//
//  DistanceEstimator.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreGraphics
import Foundation

struct DistanceEstimator {

    // Real-world heights in meters for each COCO class
    private nonisolated static let realWorldHeights: [String: Float] = [
        "person":        1.7,
        "bicycle":       1.0,
        "car":           1.5,
        "motorcycle":    1.2,
        "bus":           3.2,
        "truck":         3.5,
        "traffic light": 0.6,
        "stop sign":     0.75,
        "bench":         0.5,
        "dog":           0.5,
        "cat":           0.3,
        "backpack":      0.5,
        "umbrella":      1.0,
        "handbag":       0.4,
        "suitcase":      0.7,
        "bottle":        0.25,
        "chair":         0.9,
        "couch":         0.85,
        "potted plant":  0.4,
        "bed":           0.6,
        "dining table":  0.75,
        "laptop":        0.03,
        "cell phone":    0.15,
        "zebra crossing": 0.05
    ]

    // iPhone 13 vertical FOV approximation in radians (~55° portrait)
    private nonisolated static let verticalFOV: Float = 55.0 * .pi / 180.0

    // Estimate distance in meters from bounding box (Vision normalized coords, 0–1 range)
    nonisolated static func estimateDistance(
        label: String,
        boundingBox: CGRect,
        frameHeight: Int = 1920
    ) -> Float? {
        let realHeight = realWorldHeights[label.lowercased()] ?? 1.0
        return estimateWithHeight(realHeight, boundingBox: boundingBox)
    }

    private nonisolated static func estimateWithHeight(
        _ realHeight: Float,
        boundingBox: CGRect
    ) -> Float {
        let boxHeightRatio = Float(boundingBox.height)
        guard boxHeightRatio > 0.01 else { return 99.0 }

        // Pinhole camera: distance = realHeight / (2 * tan(vFOV/2) * boxHeightRatio)
        let distance = realHeight / (2.0 * tan(verticalFOV / 2.0) * boxHeightRatio)

        // Clamp to 0.3m – 50m
        return min(max(distance, 0.3), 50.0)
    }

    // Format distance for display
    nonisolated static func formatDistance(_ meters: Float?) -> String {
        guard let d = meters else { return "--" }
        if d < 1.0 {
            return String(format: "%.0fcm", d * 100)
        } else if d < 10.0 {
            return String(format: "%.1fm", d)
        } else {
            return String(format: "%.0fm", d)
        }
    }
}
