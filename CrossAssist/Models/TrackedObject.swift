//
//  TrackedObject.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreGraphics

/// An object tracked across multiple frames with smoothed bounding box and estimated distance.
struct TrackedObject: Identifiable, Sendable {
    let id: Int
    let label: String
    let confidence: Float
    let boundingBox: CGRect
    var distanceMeters: Float? = nil
    /// Number of consecutive frames this track has been seen. Used to suppress
    /// single-frame false positives before a box is shown in the overlay.
    var frameCount: Int = 1

    var formattedDistance: String {
        DistanceEstimator.formatDistance(distanceMeters)
    }

    /// True when object is closer than 1.5 m
    var isDangerous: Bool {
        guard let d = distanceMeters else { return false }
        return d < 1.5
    }

    /// True when object is closer than 0.8 m
    var isCritical: Bool {
        guard let d = distanceMeters else { return false }
        return d < 0.8
    }
}
