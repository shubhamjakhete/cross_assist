//
//  TrackedObject.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreGraphics

/// An object tracked across multiple frames with smoothed bounding box.
struct TrackedObject: Identifiable, Sendable {
    let id: Int
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
