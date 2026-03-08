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
    @StateObject private var cameraManager = CameraManager()
    @State private var trackedObjects: [TrackedObject] = []
    @State private var cameraPermissionGranted = false
    @State private var isInitializing = true
    @State private var detectionService: DetectionService?

    private let objectTracker = ObjectTracker()

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
                            trackedObjects: trackedObjects,
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
                    TopBarView()
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                    Spacer()
                }

                // Layer 4: Left panel — informational only
                VStack {
                    // top spacer accounts for top bar height (~50pt) + padding
                    Spacer().frame(height: 80)
                    HStack {
                        LeftPanelView(trackedObjects: trackedObjects)
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
                    BottomStatusBar(trackedObjects: trackedObjects)
                        .allowsHitTesting(false)
                        .padding(.bottom, 12)
                    BottomActionBar()
                }
            }
        }
        .onAppear {
            do {
                detectionService = try DetectionService.create()
                print("✅ DetectionService created and ready")
            } catch {
                print("❌ Failed to create DetectionService: \(error)")
            }
            checkCameraPermission()
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { isInitializing = false }
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
                let detections = await service.detect(frame: frame)
                let tracked   = await objectTracker.update(detections: detections)
                await MainActor.run {
                    trackedObjects = tracked
                    print("🟢 Tracked objects count: \(trackedObjects.count)")
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
