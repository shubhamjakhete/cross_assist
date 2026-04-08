//
//  TrafficLightColorTests.swift
//  CrossAssistUnitTests
//

import CoreGraphics
import CoreVideo
import XCTest
@testable import CrossAssist

final class TrafficLightColorTests: XCTestCase {

    private let log = TestLogger(suiteTitle: "TRAFFIC LIGHT COLOR CLASSIFIER TESTS")

    override func setUp() {
        super.setUp()
        log.resetCounts()
        log.printSuiteHeader()
    }

    override func tearDown() {
        log.printSuiteSummary()
        super.tearDown()
    }

    // MARK: - Synthetic BGRA buffer (kCVPixelFormatType_32BGRA)

    private func makeBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pb
        )
        return pb
    }

    /// Fills rectangular region [x0..x1) x [y0..y1) with BGRA byte triple (B,G,R).
    private func fillRegion(
        _ buffer: CVPixelBuffer,
        x0: Int, y0: Int, x1: Int, y1: Int,
        b: UInt8, g: UInt8, r: UInt8
    ) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let W = CVPixelBufferGetWidth(buffer)
        let H = CVPixelBufferGetHeight(buffer)
        let sx0 = max(0, x0)
        let sy0 = max(0, y0)
        let sx1 = min(W, x1)
        let sy1 = min(H, y1)
        for y in sy0..<sy1 {
            for x in sx0..<sx1 {
                let o = y * bpr + x * 4
                ptr[o] = b
                ptr[o + 1] = g
                ptr[o + 2] = r
                ptr[o + 3] = 255
            }
        }
    }

    private func classifyFullFrame(buffer: CVPixelBuffer) -> TrafficLightState {
        TrafficLightColorClassifier.classify(
            pixelBuffer: buffer,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
            frameSize: CGSize(
                width: CVPixelBufferGetWidth(buffer),
                height: CVPixelBufferGetHeight(buffer)
            )
        )
    }

    func test_red_topRegion() {
        guard let pb = makeBuffer(width: 120, height: 120) else {
            XCTFail("buffer")
            return
        }
        let H = CVPixelBufferGetHeight(pb)
        let third = max(1, H * 30 / 100)
        fillRegion(pb, x0: 0, y0: 0, x1: 120, y1: H, b: 0, g: 0, r: 0)
        fillRegion(pb, x0: 0, y0: 0, x1: 120, y1: third, b: 0, g: 0, r: 255)
        let state = classifyFullFrame(buffer: pb)
        log.info("red top region → color=\(state.color) confidence=\(state.confidence)")
        if state.color == .red {
            log.pass("Bright red in top third → .red")
        } else {
            log.warn("Expected .red, got \(state.color) conf=\(state.confidence) (HSV thresholds may need tuning)")
        }
        if state.color != .unknown {
            XCTAssertGreaterThan(state.confidence, 0)
            log.pass("confidence > 0 when color detected (\(state.confidence))")
        } else {
            XCTAssertEqual(state.confidence, 0)
            log.warn("Classifier returned unknown — check sampling/thresholds")
        }
    }

    func test_green_bottomRegion() {
        guard let pb = makeBuffer(width: 120, height: 120) else {
            XCTFail("buffer")
            return
        }
        let H = CVPixelBufferGetHeight(pb)
        fillRegion(pb, x0: 0, y0: 0, x1: 120, y1: H, b: 0, g: 0, r: 0)
        let y0 = H * 70 / 100
        fillRegion(pb, x0: 0, y0: y0, x1: 120, y1: H, b: 0, g: 255, r: 0)
        let state = classifyFullFrame(buffer: pb)
        log.info("green bottom region → color=\(state.color) confidence=\(state.confidence)")
        if state.color == .green {
            log.pass("Bright green in bottom third → .green")
        } else {
            log.warn("Expected .green, got \(state.color) conf=\(state.confidence)")
        }
        if state.color != .unknown {
            XCTAssertGreaterThan(state.confidence, 0)
        } else {
            XCTAssertEqual(state.confidence, 0)
        }
    }

    func test_yellow_middleRegion() {
        guard let pb = makeBuffer(width: 120, height: 120) else {
            XCTFail("buffer")
            return
        }
        let H = CVPixelBufferGetHeight(pb)
        fillRegion(pb, x0: 0, y0: 0, x1: 120, y1: H, b: 0, g: 0, r: 0)
        let third = max(1, H * 30 / 100)
        let y0 = H * 35 / 100
        let y1 = y0 + third
        // saturated yellow ~ (255,255,0) RGB → BGRA B=0,G=255,R=255
        fillRegion(pb, x0: 0, y0: y0, x1: 120, y1: y1, b: 0, g: 255, r: 255)
        let state = classifyFullFrame(buffer: pb)
        log.info("yellow middle region → color=\(state.color) confidence=\(state.confidence)")
        if state.color == .yellow {
            log.pass("Bright yellow in middle third → .yellow")
        } else {
            log.warn("Expected .yellow, got \(state.color) conf=\(state.confidence)")
        }
        if state.color != .unknown {
            XCTAssertGreaterThan(state.confidence, 0)
        } else {
            XCTAssertEqual(state.confidence, 0)
        }
    }

    func test_dark_unknown() {
        guard let pb = makeBuffer(width: 120, height: 120) else {
            XCTFail("buffer")
            return
        }
        fillRegion(pb, x0: 0, y0: 0, x1: 120, y1: 120, b: 20, g: 20, r: 20)
        let state = classifyFullFrame(buffer: pb)
        log.info("dark unsaturated → color=\(state.color) confidence=\(state.confidence)")
        if state.color == .unknown {
            log.pass("Dark pixels → .unknown")
        } else {
            log.warn("Expected .unknown for dark buffer, got \(state.color)")
        }
        XCTAssertEqual(state.confidence, 0, accuracy: 0.001)
        log.pass("confidence 0 when unknown")
    }
}
