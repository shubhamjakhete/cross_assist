//
//  CameraManager.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import ARKit
import Combine

/// Manages the ARKit camera session and publishes frames for processing.
/// Uses a DROP strategy: if busy, skips the frame.
@MainActor
final class CameraManager: NSObject, ObservableObject {
    private nonisolated(unsafe) let session = ARSession()

    /// Exposes the ARSession for use by CameraPreviewView.
    var arSession: ARSession { session }
    private nonisolated(unsafe) var isProcessing = false

    @Published private(set) var latestFrame: CameraFrame?

    func start() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []

        guard ARWorldTrackingConfiguration.isSupported else {
            print("[CameraManager] ARWorldTrackingConfiguration is not supported on this device")
            return
        }

        session.delegate = self
        Task.detached { [weak self] in
            self?.session.run(config)
        }
    }

    func stop() {
        session.pause()
    }
}

extension CameraManager: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard !isProcessing else { return }
        isProcessing = true

        let pixelBuffer = frame.capturedImage
        let timestamp = frame.timestamp
        let cameraFrame = CameraFrame(pixelBuffer: pixelBuffer, timestamp: timestamp)

        Task { @MainActor in
            self.latestFrame = cameraFrame
            self.isProcessing = false
        }
    }
}
