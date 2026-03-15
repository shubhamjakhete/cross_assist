//
//  TrafficLightColorClassifier.swift
//  CrossAssist
//

import CoreGraphics
import CoreVideo

// MARK: - TrafficLightState

/// The detected state of a traffic light in one frame.
struct TrafficLightState: Sendable, Equatable {

    // Four possible states; `unknown` means the classifier cannot decide.
    enum Color: Sendable, Equatable {
        case red, green, yellow, unknown

        // Explicit nonisolated == prevents Swift 6 from inferring the
        // synthesized witness as @MainActor-isolated when the type is first
        // used inside a SwiftUI View's onChange(of:) closure.
        nonisolated static func == (lhs: Color, rhs: Color) -> Bool {
            switch (lhs, rhs) {
            case (.red,     .red),
                 (.green,   .green),
                 (.yellow,  .yellow),
                 (.unknown, .unknown): return true
            default:                   return false
            }
        }
    }

    let color: Color
    let confidence: Float

    var displayText: String {
        switch color {
        case .red:     return "RED"
        case .green:   return "GREEN"
        case .yellow:  return "YELLOW"
        case .unknown: return "?"
        }
    }
}

// MARK: - TrafficLightColorClassifier

/// Pure static classifier — no state, no actor, all methods nonisolated.
/// Analyses the three vertical thirds of a traffic-light bounding box to
/// determine which bulb (red/yellow/green) is lit.
struct TrafficLightColorClassifier {

    // MARK: - Public

    /// Classify a traffic light from a raw pixel buffer.
    ///
    /// - Parameters:
    ///   - pixelBuffer: kCVPixelFormatType_32BGRA buffer from ARFrame.
    ///   - boundingBox: Vision-normalised bbox (origin bottom-left, 0–1).
    ///   - frameSize:   Logical frame dimensions used for coordinate conversion.
    /// - Returns: Best-guess `TrafficLightState`.
    nonisolated static func classify(
        pixelBuffer: CVPixelBuffer,
        boundingBox: CGRect,
        frameSize: CGSize
    ) -> TrafficLightState {
        // Use actual buffer dimensions for pixel-accurate conversion.
        let bufW = CVPixelBufferGetWidth(pixelBuffer)
        let bufH = CVPixelBufferGetHeight(pixelBuffer)

        // Convert Vision bbox (bottom-left origin) → pixel rect (top-left origin).
        let px = Int(boundingBox.minX * CGFloat(bufW))
        let py = Int((1.0 - boundingBox.maxY) * CGFloat(bufH))
        let pw = max(1, Int(boundingBox.width  * CGFloat(bufW)))
        let ph = max(1, Int(boundingBox.height * CGFloat(bufH)))

        let third = max(1, ph * 30 / 100)   // 30% of bbox height

        // Red  → top 30%  (y offset: 0%)
        let topRegion    = CGRect(x: px, y: py,              width: pw, height: third)
        // Yellow → mid 30%  (y offset: 35%)
        let middleRegion = CGRect(x: px, y: py + ph * 35 / 100, width: pw, height: third)
        // Green  → bot 30%  (y offset: 70%)
        let bottomRegion = CGRect(x: px, y: py + ph * 70 / 100, width: pw, height: third)

        let redScore    = analyzeRegion(pixelBuffer: pixelBuffer, region: topRegion,    targetHue: .red)
        let yellowScore = analyzeRegion(pixelBuffer: pixelBuffer, region: middleRegion, targetHue: .yellow)
        let greenScore  = analyzeRegion(pixelBuffer: pixelBuffer, region: bottomRegion, targetHue: .green)

        let threshold: Float = 0.06

        let candidates: [(TrafficLightState.Color, Float)] = [
            (.red, redScore), (.yellow, yellowScore), (.green, greenScore)
        ]
        guard let best = candidates.max(by: { $0.1 < $1.1 }), best.1 >= threshold else {
            return TrafficLightState(color: .unknown, confidence: 0)
        }
        return TrafficLightState(color: best.0, confidence: best.1)
    }

    // MARK: - Region analysis

    /// Returns the fraction of sampled pixels in `region` whose hue matches
    /// `targetHue`.  Only considers lit pixels (value > 0.35, saturation > 0.30).
    nonisolated static func analyzeRegion(
        pixelBuffer: CVPixelBuffer,
        region: CGRect,
        targetHue: TrafficLightState.Color
    ) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }

        let bpr    = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bufW   = CVPixelBufferGetWidth(pixelBuffer)
        let bufH   = CVPixelBufferGetHeight(pixelBuffer)
        let ptr    = base.assumingMemoryBound(to: UInt8.self)

        let startX = max(0, Int(region.minX))
        let startY = max(0, Int(region.minY))
        let endX   = min(bufW - 1, Int(region.maxX))
        let endY   = min(bufH - 1, Int(region.maxY))

        guard startX < endX, startY < endY else { return 0 }

        var matched = 0
        var total   = 0
        let step    = 3  // sample every 3rd pixel

        for y in stride(from: startY, to: endY, by: step) {
            for x in stride(from: startX, to: endX, by: step) {
                let off = y * bpr + x * 4
                // BGRA byte order
                let b = Float(ptr[off])     / 255.0
                let g = Float(ptr[off + 1]) / 255.0
                let r = Float(ptr[off + 2]) / 255.0

                let (h, s, v) = rgbToHSV(r: r, g: g, b: b)

                total += 1
                // Ignore dark / unsaturated pixels — they are not a lit bulb.
                guard v > 0.20, s > 0.20 else { continue }
                if matchesHue(h: h, color: targetHue) { matched += 1 }
            }
        }

        guard total > 0 else { return 0 }
        return Float(matched) / Float(total)
    }

    // MARK: - HSV helpers

    /// Converts linear RGB (0–1) to HSV; returns H in 0–360°, S and V in 0–1.
    nonisolated private static func rgbToHSV(r: Float, g: Float, b: Float) -> (Float, Float, Float) {
        let vMax = max(r, g, b)
        let vMin = min(r, g, b)
        let delta = vMax - vMin

        let v = vMax
        let s: Float = vMax > 0 ? delta / vMax : 0

        var h: Float = 0
        if delta > 0 {
            if vMax == r {
                h = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if vMax == g {
                h = 60 * ((b - r) / delta + 2)
            } else {
                h = 60 * ((r - g) / delta + 4)
            }
            if h < 0 { h += 360 }
        }
        return (h, s, v)
    }

    /// Returns true when hue `h` (0–360°) is within the expected range for a
    /// given traffic-light bulb colour.
    nonisolated private static func matchesHue(h: Float, color: TrafficLightState.Color) -> Bool {
        switch color {
        case .red:     return h <= 25 || h >= 335   // wraps around 0°
        case .yellow:  return h >= 20 && h <= 70
        case .green:   return h >= 80 && h <= 170
        case .unknown: return false
        }
    }
}
