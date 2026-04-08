//
//  WalkSignalTests.swift
//  CrossAssistUnitTests
//

import XCTest
@testable import CrossAssist

final class WalkSignalTests: XCTestCase {

    private let log = TestLogger(suiteTitle: "WALK SIGNAL RECOMMENDATION TESTS")

    override func setUp() {
        super.setUp()
        log.resetCounts()
        log.printSuiteHeader()
    }

    override func tearDown() {
        log.printSuiteSummary()
        super.tearDown()
    }

    private func map(_ seconds: Int) -> WalkSignalRecommendation {
        WalkSignalTimerService.mapToRecommendation(seconds: seconds)
    }

    func test_map_15_safeToCross() {
        let r = map(15)
        if case .safeToCross(let s) = r, s == 15 {
            log.pass("15 s → safeToCross(15)")
        } else {
            log.fail("expected safeToCross(15), got \(r)")
            XCTFail("mapping mismatch")
        }
    }

    func test_map_8_hurry() {
        let r = map(8)
        if case .hurry(let s) = r, s == 8 {
            log.pass("8 s → hurry(8)")
        } else {
            log.fail("expected hurry(8), got \(r)")
            XCTFail()
        }
    }

    func test_map_2_tooLate() {
        let r = map(2)
        if case .tooLate(let s) = r, s == 2 {
            log.pass("2 s → tooLate(2)")
        } else {
            log.fail("expected tooLate(2), got \(r)")
            XCTFail()
        }
    }

    func test_map_0_waitForNext() {
        let r = map(0)
        if case .waitForNext = r {
            log.pass("0 s → waitForNext")
        } else {
            log.fail("expected waitForNext, got \(r)")
            XCTFail()
        }
    }

    func test_boundary_11_safeNotHurry() {
        let r = map(11)
        if case .safeToCross(11) = r {
            log.pass("11 s → safeToCross (not hurry)")
        } else {
            log.fail("got \(r)")
            XCTFail()
        }
    }

    func test_boundary_10_hurryNotSafe() {
        let r = map(10)
        if case .hurry(10) = r {
            log.pass("10 s → hurry (not safeToCross)")
        } else {
            log.fail("got \(r)")
            XCTFail()
        }
    }

    func test_boundary_4_hurryNotTooLate() {
        let r = map(4)
        if case .hurry(4) = r {
            log.pass("4 s → hurry (not tooLate)")
        } else {
            log.fail("got \(r)")
            XCTFail()
        }
    }

    func test_boundary_3_tooLateNotHurry() {
        let r = map(3)
        if case .tooLate(3) = r {
            log.pass("3 s → tooLate (not hurry)")
        } else {
            log.fail("got \(r)")
            XCTFail()
        }
    }

    func test_urgencyOrdering() {
        let tooLate = WalkSignalRecommendation.tooLate(seconds: 2).urgency
        let hurry = WalkSignalRecommendation.hurry(seconds: 5).urgency
        let safe = WalkSignalRecommendation.safeToCross(seconds: 20).urgency
        let solid = WalkSignalRecommendation.safeNoCountdown.urgency
        XCTAssertGreaterThan(tooLate, hurry)
        XCTAssertGreaterThan(hurry, safe)
        XCTAssertEqual(safe, solid, "safeToCross and safeNoCountdown share baseline urgency in model")
        log.pass("urgency: tooLate(\(tooLate)) > hurry(\(hurry)) > safeToCross/safeNoCountdown (\(safe))")
    }

    func test_waitForNextUrgency_vs_tooLate() {
        let w = WalkSignalRecommendation.waitForNext.urgency
        let t = WalkSignalRecommendation.tooLate(seconds: 1).urgency
        XCTAssertGreaterThanOrEqual(w, t)
        log.pass("waitForNext urgency \(w) ≥ tooLate urgency \(t)")
    }

    func test_displayText_safeToCross_containsSeconds() {
        let t = WalkSignalRecommendation.safeToCross(seconds: 12).displayText
        XCTAssertTrue(t.contains("12"), t)
        log.pass("displayText safeToCross(12) → \"\(t)\"")
    }

    func test_displayText_hurry_containsSeconds() {
        let t = WalkSignalRecommendation.hurry(seconds: 7).displayText
        XCTAssertTrue(t.contains("7"), t)
        log.pass("displayText hurry(7) → \"\(t)\"")
    }

    func test_colorHex_safeToCross_green() {
        XCTAssertEqual(WalkSignalRecommendation.safeToCross(seconds: 12).colorHex, "22C55E")
        log.pass("colorHex safeToCross → green 22C55E")
    }

    func test_colorHex_tooLate_red() {
        XCTAssertEqual(WalkSignalRecommendation.tooLate(seconds: 2).colorHex, "EF4444")
        log.pass("colorHex tooLate → red EF4444")
    }
}
