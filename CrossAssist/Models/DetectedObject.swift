//
//  DetectedObject.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreGraphics
import Foundation

/// A single object detected in a frame.
/// Bounding box uses Vision normalized coordinates (origin bottom-left).
struct DetectedObject: Identifiable, Sendable {
    let id: UUID
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
