//
//  CameraManager.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import ARKit
import Combine
import CoreMotion

/// Manages the ARKit camera session and publishes frames for processing.
/// Uses a DROP strategy: if busy, skips the frame.
/// Throttles how often frames are published based on accelerometer-derived motion
/// (fast walk → every frame, slow → every 2nd, stationary → every 3rd).
@MainActor
final class CameraManager: NSObject, ObservableObject {
    private nonisolated(unsafe) let session = ARSession()

    /// Exposes the ARSession for use by CameraPreviewView.
    var arSession: ARSession { session }
    private nonisolated(unsafe) var isProcessing = false

    private let motionManager = CMMotionManager()
    /// Read from ARSession thread in `didUpdate`; written on main from accelerometer.
    private nonisolated(unsafe) var currentFrameInterval: Int = 1
    private nonisolated(unsafe) var motionFrameCounter: Int = 0

    @Published private(set) var latestFrame: CameraFrame?

    func start() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []

        guard ARWorldTrackingConfiguration.isSupported else {
            print("[CameraManager] ARWorldTrackingConfiguration is not supported on this device")
            return
        }

        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.5
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let data else { return }
                let magnitude = sqrt(
                    data.acceleration.x * data.acceleration.x +
                        data.acceleration.y * data.acceleration.y +
                        data.acceleration.z * data.acceleration.z
                )
                let motion = abs(magnitude - 1.0)

                if motion > 0.25 {
                    self?.currentFrameInterval = 1
                } else if motion > 0.08 {
                    self?.currentFrameInterval = 2
                } else {
                    self?.currentFrameInterval = 3
                }
            }
        }

        session.delegate = self
        Task.detached { [weak self] in
            self?.session.run(config)
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        session.pause()
    }
}

extension CameraManager: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        motionFrameCounter += 1
        let interval = max(1, currentFrameInterval)
        guard motionFrameCounter % interval == 0 else { return }

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
