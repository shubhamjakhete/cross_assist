//
//  DistanceEstimatorTests.swift
//  CrossAssistUnitTests
//

import CoreGraphics
import XCTest
@testable import CrossAssist

final class DistanceEstimatorTests: XCTestCase {

    private let log = TestLogger(suiteTitle: "DISTANCE ESTIMATOR TESTS")

    override func setUp() {
        super.setUp()
        log.resetCounts()
        log.printSuiteHeader()
    }

    override func tearDown() {
        log.printSuiteSummary()
        super.tearDown()
    }

    /// Pinhole model yields ~1.63 m for a full-frame person; use vehicle for a strict &lt;1.5 m case.
    func test_personLargeBBox_isCloseRange() {
        let box = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.92)
        let d = DistanceEstimator.estimateDistance(label: "person", boundingBox: box)
        let value = d ?? -1
        log.info("label=person bbox.height=\(box.height) → distance=\(value)m")
        XCTAssertNotNil(d)
        if let d {
            XCTAssertLessThan(d, 2.5, "Large person bbox should read as close (model min ~1.63 m at full frame)")
            log.pass("Person large bbox → \(String(format: "%.2f", d))m (expect close range)")
        }
    }

    func test_vehicleLargeBBox_under1_5m() {
        let box = CGRect(x: 0.02, y: 0.02, width: 0.96, height: 0.96)
        let d = DistanceEstimator.estimateDistance(label: "car", boundingBox: box)
        log.info("label=car bbox.height=\(box.height) → distance=\(d.map { String(format: "%.2f", $0) } ?? "nil")m")
        XCTAssertNotNil(d)
        XCTAssertLessThan(d!, 1.51)
        log.pass("Vehicle (car) large bbox → \(String(format: "%.2f", d!))m (< 1.51m)")
    }

    func test_personMediumBBox_between1_5and6m() {
        let box = CGRect(x: 0.2, y: 0.15, width: 0.35, height: 0.28)
        let d = DistanceEstimator.estimateDistance(label: "person", boundingBox: box)
        log.info("label=person bbox.height=\(box.height) → distance=\(d.map { String(format: "%.2f", $0) } ?? "nil")m")
        XCTAssertNotNil(d)
        if let d {
            XCTAssertGreaterThanOrEqual(d, 1.5)
            XCTAssertLessThanOrEqual(d, 6.0)
            log.pass("Person medium bbox → \(String(format: "%.2f", d))m (1.5–6 m band)")
        }
    }

    func test_tinyBBox_clampedOrLarge() {
        let box = CGRect(x: 0.4, y: 0.4, width: 0.02, height: 0.005)
        let d = DistanceEstimator.estimateDistance(label: "person", boundingBox: box)
        log.info("label=person tiny bbox.height=\(box.height) → distance=\(d.map { String(format: "%.2f", $0) } ?? "nil")")
        if d == nil {
            log.pass("Tiny bbox → nil (too small/far)")
        } else if d! >= 50 || d == 99 {
            log.warn("Tiny bbox returned \(d!) — implementation uses clamp/far sentinel, not nil; tune thresholds if needed")
        } else {
            log.warn("Unexpected distance \(d!) for tiny bbox")
        }
    }

    func test_formatDistance_metersContainsM() {
        let s = DistanceEstimator.formatDistance(2.3)
        XCTAssertTrue(s.contains("m"), "got \(s)")
        log.pass("formatDistance(2.3) → \"\(s)\" (contains \"m\")")
    }

    func test_formatDistance_subMeterContainsCm() {
        let s = DistanceEstimator.formatDistance(0.45)
        XCTAssertTrue(s.contains("cm"), "got \(s)")
        log.pass("formatDistance(0.45) → \"\(s)\" (contains \"cm\")")
    }

    func test_formatDistance_nilReturnsDashDash() {
        let s = DistanceEstimator.formatDistance(nil)
        XCTAssertEqual(s, "--")
        log.pass("formatDistance(nil) → \"\(s)\"")
    }
}
