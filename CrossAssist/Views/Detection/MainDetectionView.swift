//
//  MainDetectionView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import AVFoundation
import Combine
import SwiftUI

struct MainDetectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var trackedObjects: [TrackedObject] = []
    @State private var cameraPermissionGranted = false
    @State private var isInitializing = true
    @State private var detectionService: DetectionService?
    @State private var depthService: DepthEstimationService?
    @State private var depthFrameCounter = 0
    @State private var showSettings  = false
    @State private var showCrossing  = false
    @State private var showEmergency = false
    @State private var showHistory   = false

    private let objectTracker = ObjectTracker()

    /// Only show boxes that have been stable for at least 3 consecutive frames,
    /// eliminating single-frame false positives.
    private var stableObjects: [TrackedObject] {
        trackedObjects.filter { $0.frameCount >= 5 }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Layer 0: Black fallback background ──────────────────────
            Color.black.ignoresSafeArea()

            // ── Layer 1 + 2: Camera feed + bounding box overlay ─────────
            if cameraPermissionGranted && !isInitializing {
                GeometryReader { geo in
                    ZStack {
                        CameraPreviewView(session: cameraManager.arSession)
                            .ignoresSafeArea()

                        OverlayView(
                            trackedObjects: stableObjects,
                            viewSize: geo.size
                        )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    }
                }
                .ignoresSafeArea()
            }

            // ── Loading / permission states ─────────────────────────────
            if isInitializing {
                Text("Starting camera...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            } else if !cameraPermissionGranted {
                Text("Tap to enable camera")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .onTapGesture { openSettings() }
            }

            // ── UI overlay layers (visible once init done) ──────────────
            if !isInitializing {
                // Layer 3: Top bar — interactive
                VStack {
                    TopBarView(onSOSTapped: { showEmergency = true })
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                    Spacer()
                }

                // Layer 4: Left panel — informational only
                VStack {
                    // top spacer accounts for top bar height (~50pt) + padding
                    Spacer().frame(height: 80)
                    HStack {
                        LeftPanelView(trackedObjects: stableObjects)
                            .padding(.leading, 16)
                        Spacer()
                    }
                    // bottom spacer accounts for status bar + action bar + tab bar
                    Spacer().frame(height: 180)
                }
                .allowsHitTesting(false)

                // Layer 5 + 6: Bottom status bar + action bar
                VStack(spacing: 0) {
                    Spacer()
                    BottomStatusBar(trackedObjects: stableObjects)
                        .allowsHitTesting(false)
                        .padding(.bottom, 12)
                    BottomActionBar(
                        onSettingsTapped:   { showSettings  = true },
                        onMapTapped:        { showCrossing  = true },
                        onStopLongPress:    { showEmergency = true },
                        onStopTapped:       { dismiss() },
                        onTabHistoryTapped: { showHistory   = true },
                        onTabProfileTapped: { showSettings  = true }
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showCrossing) {
            CrossingGuidanceView()
        }
        .fullScreenCover(isPresented: $showEmergency) {
            EmergencyView()
        }
        .fullScreenCover(isPresented: $showHistory) {
            PlaceholderView(title: "History")
        }
        .task {
            // Load YOLO synchronously — fast, already @MainActor
            do {
                detectionService = try DetectionService.create()
                print("✅ DetectionService created and ready")
            } catch {
                print("❌ Failed to create DetectionService: \(error)")
            }
            // Start camera immediately after YOLO is ready
            checkCameraPermission()
            try? await Task.sleep(for: .seconds(2))
            isInitializing = false

            // Load 49MB depth model in background so camera is unblocked
            Task.detached(priority: .background) { [self] in
                let depth = await MainActor.run { try? DepthEstimationService.create() }
                guard let depth else { return }
                await self.objectTracker.setDepthService(depth)
                await MainActor.run { self.depthService = depth }
                print("✅ DepthEstimationService ready")
            }
        }
        .onReceive(cameraManager.$latestFrame) { frame in
            guard let frame = frame else { return }
            print("📷 Frame received, running detection")
            Task {
                guard let service = detectionService else {
                    print("❌ DetectionService is nil — YOLO model failed to load")
                    return
                }

                // ── Step 1: YOLO detection + IoU tracking (heuristic distance) ──
                let detections = await service.detect(frame: frame)
                let tracked    = await objectTracker.update(detections: detections, frame: frame)
                await MainActor.run {
                    trackedObjects = tracked
                    print("🟢 Tracked objects count: \(trackedObjects.count)")
                    let zebraDetected = tracked.contains { $0.label.lowercased().contains("zebra") }
                    if zebraDetected && !showCrossing { showCrossing = true }
                }

                // ── Step 2: Depth Anything V2 enrichment (every 8th frame, fully detached) ──
                depthFrameCounter += 1
                guard depthFrameCounter % 8 == 0, !tracked.isEmpty else { return }
                guard let depthSvc = depthService else { return }

                // Capture Sendable values before leaving @MainActor context
                let capturedTracked = tracked
                let capturedFrame   = frame
                Task.detached(priority: .utility) { [self] in
                    var enriched = capturedTracked
                    for i in enriched.indices {
                        if let depth = await depthSvc.estimateDepth(
                            pixelBuffer: capturedFrame.pixelBuffer,
                            boundingBox: enriched[i].boundingBox
                        ) {
                            enriched[i].distanceMeters = depth
                        }
                    }
                    let final = enriched  // immutable snapshot — safe to cross into MainActor.run
                    await MainActor.run { [self] in
                        self.trackedObjects = final
                        print("📐 Depth enrichment done — \(final.count) objects")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
            cameraManager.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    cameraPermissionGranted = granted
                    if granted { cameraManager.start() }
                }
            }
        case .denied, .restricted:
            cameraPermissionGranted = false
        @unknown default:
            cameraPermissionGranted = false
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    MainDetectionView()
}
