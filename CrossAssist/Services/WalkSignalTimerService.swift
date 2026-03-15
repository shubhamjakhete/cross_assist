//
//  WalkSignalTimerService.swift
//  CrossAssist
//

import CoreImage
import CoreVideo
import Foundation
import Vision

// MARK: - WalkSignalRecommendation

enum WalkSignalRecommendation: Equatable, Sendable {
    case safeToCross(seconds: Int)   // > 10 s remaining
    case hurry(seconds: Int)         // 4 – 10 s remaining
    case tooLate(seconds: Int)       // 1 – 3 s remaining
    case waitForNext                 // 0 s or signal just ended
    case safeNoCountdown             // solid WALK figure, no number visible
    case unknown                     // no signal or OCR failed

    var displayText: String {
        switch self {
        case .safeToCross(let s): return "CROSS NOW • \(s)s"
        case .hurry(let s):       return "HURRY • \(s)s left"
        case .tooLate(let s):     return "Too late • \(s)s — wait"
        case .waitForNext:        return "Wait for next signal"
        case .safeNoCountdown:    return "Safe to cross"
        case .unknown:            return ""
        }
    }

    var colorHex: String {
        switch self {
        case .safeToCross, .safeNoCountdown: return "22C55E"
        case .hurry:                         return "F97316"
        case .tooLate, .waitForNext:         return "EF4444"
        case .unknown:                       return "9CA3AF"
        }
    }

    /// Higher urgency = shown first in the status bar priority order.
    var urgency: Int {
        switch self {
        case .unknown:         return -1
        case .safeToCross:     return  0
        case .safeNoCountdown: return  0
        case .hurry:           return  1
        case .tooLate:         return  2
        case .waitForNext:     return  3
        }
    }

    var detectedSeconds: Int? {
        switch self {
        case .safeToCross(let s), .hurry(let s), .tooLate(let s): return s
        default: return nil
        }
    }

    var shouldShowInStatusBar: Bool { self != .unknown }
}

// MARK: - WalkSignalTimerService

struct WalkSignalTimerService {

    // MARK: Public entry point

    /// Crop the pixel buffer around the pedestrian signal bbox (with right-side
    /// expansion to capture the adjacent countdown panel), run OCR, and return
    /// the appropriate crossing recommendation.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Full-resolution camera frame.
    ///   - boundingBox: Vision-normalised bbox (bottom-left origin, 0–1 range).
    ///   - frameSize:   Pixel dimensions of the full camera frame.
    nonisolated static func detectCountdown(
        pixelBuffer: CVPixelBuffer,
        boundingBox: CGRect,
        frameSize: CGSize
    ) -> WalkSignalRecommendation {

        // Step 1 — Vision bbox is bottom-left origin; flip to UIKit top-left.
        let flippedBox = CGRect(
            x: boundingBox.minX,
            y: 1.0 - boundingBox.maxY,
            width: boundingBox.width,
            height: boundingBox.height
        )

        // Step 2 — Asymmetric expansion.
        // The countdown number panel sits IMMEDIATELY to the right of the figure
        // panel that YOLO detected, so we expand heavily rightward (+80 %).
        let minX = max(0.0, flippedBox.minX - 0.10 * flippedBox.width)
        let minY = max(0.0, flippedBox.minY - 0.15 * flippedBox.height)
        // width = original + 10 % left + 80 % right = × 1.90; clamp at right edge.
        let rawWidth  = flippedBox.width  * 1.90
        let rawHeight = flippedBox.height * 1.30
        let clampedWidth  = min(1.0 - minX, rawWidth)
        let clampedHeight = min(1.0 - minY, rawHeight)
        let expandedBox = CGRect(x: minX, y: minY,
                                 width: clampedWidth, height: clampedHeight)

        // Step 3 — Convert normalised coords to pixel coords.
        let pixelBox = CGRect(
            x: expandedBox.minX * frameSize.width,
            y: expandedBox.minY * frameSize.height,
            width: expandedBox.width  * frameSize.width,
            height: expandedBox.height * frameSize.height
        )

        // Step 4 — Crop.
        guard let croppedImage = cropPixelBuffer(pixelBuffer, to: pixelBox) else {
            return .unknown
        }

        // Steps 5 & 6 — OCR.
        guard let seconds = runOCR(on: croppedImage) else {
            // No number detected → solid WALK figure → safe to cross.
            return .safeNoCountdown
        }

        // Step 7 — Map the detected digit to a recommendation.
        return mapToRecommendation(seconds: seconds)
    }

    // MARK: Internal helpers

    nonisolated static func mapToRecommendation(seconds: Int) -> WalkSignalRecommendation {
        switch seconds {
        case 11...:  return .safeToCross(seconds: seconds)
        case 4...10: return .hurry(seconds: seconds)
        case 1...3:  return .tooLate(seconds: seconds)
        case 0:      return .waitForNext
        default:     return .unknown
        }
    }

    /// Crop a `CVPixelBuffer` to `rect` (UIKit pixel coordinates, top-left origin).
    private nonisolated static func cropPixelBuffer(
        _ buffer: CVPixelBuffer,
        to rect: CGRect
    ) -> CGImage? {
        let bufW = CGFloat(CVPixelBufferGetWidth(buffer))
        let bufH = CGFloat(CVPixelBufferGetHeight(buffer))

        // Clamp to buffer bounds.
        let cx = max(0, min(rect.minX, bufW - 1))
        let cy = max(0, min(rect.minY, bufH - 1))
        let cw = max(1, min(rect.width,  bufW - cx))
        let ch = max(1, min(rect.height, bufH - cy))
        let clampedRect = CGRect(x: cx, y: cy, width: cw, height: ch)

        // CIImage uses bottom-left origin — flip Y from UIKit top-left.
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let ciRect  = CGRect(
            x: clampedRect.minX,
            y: bufH - clampedRect.maxY,
            width: clampedRect.width,
            height: clampedRect.height
        )

        let cropped = ciImage.cropped(to: ciRect)
        guard !cropped.extent.isEmpty else { return nil }
        return CIContext().createCGImage(cropped, from: cropped.extent)
    }

    /// Run Vision OCR on a `CGImage` and return the first detected integer (0–99),
    /// or `nil` if no number is found.
    ///
    /// `VNImageRequestHandler.perform()` is synchronous, so the semaphore is
    /// signalled inside the handler before `perform()` returns.  The
    /// `semaphore.wait()` therefore returns immediately and acts as a memory
    /// barrier ensuring the result is visible after the call.
    private nonisolated static func runOCR(on image: CGImage) -> Int? {
        var detectedNumber: Int? = nil
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation]
            else { return }

            for obs in observations {
                guard let candidate = obs.topCandidates(1).first?.string else { continue }
                let text = candidate.trimmingCharacters(in: .whitespaces)

                // Try direct integer parse first.
                if let n = Int(text), (0...99).contains(n) {
                    detectedNumber = n
                    return
                }

                // Strip non-digit characters and try again.
                let digits = text
                    .components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                if !digits.isEmpty, let n = Int(digits), (0...99).contains(n) {
                    detectedNumber = n
                    return
                }
            }
        }
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.08

        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
        } catch {
            semaphore.signal()  // avoid deadlock on perform failure
        }

        _ = semaphore.wait(timeout: .now() + 0.15)
        return detectedNumber
    }
}
