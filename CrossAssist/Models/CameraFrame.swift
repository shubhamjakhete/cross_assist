//
//  CameraFrame.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreVideo

/// A snapshot of camera output for processing.
/// Marked @unchecked Sendable for safe crossing of actor boundaries.
struct CameraFrame: @unchecked Sendable {
    nonisolated(unsafe) let pixelBuffer: CVPixelBuffer
    let timestamp: Double
}
