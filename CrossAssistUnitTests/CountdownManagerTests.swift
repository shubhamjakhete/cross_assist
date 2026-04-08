//
//  CountdownManagerTests.swift
//  CrossAssistUnitTests
//

import XCTest
@testable import CrossAssist

@MainActor
final class CountdownManagerTests: XCTestCase {

    private let log = TestLogger(suiteTitle: "WALK SIGNAL COUNTDOWN MANAGER TESTS")

    private var manager: WalkSignalCountdownManager { WalkSignalCountdownManager.shared }

    override func setUp() {
        super.setUp()
        log.resetCounts()
        log.printSuiteHeader()
        manager.resetForUnitTesting()
    }

    override func tearDown() {
        manager.resetForUnitTesting()
        log.printSuiteSummary()
        super.tearDown()
    }

    func test_updateFromOCR_setsSeconds() {
        manager.resetForUnitTesting()
        manager.updateFromOCR(8)
        XCTAssertEqual(manager.currentSeconds, 8)
        log.pass("updateFromOCR(8) → currentSeconds 8")
    }

    func test_smallDrift_doesNotResetFromOCR() {
        manager.resetForUnitTesting()
        manager.updateFromOCR(8)
        manager.updateFromOCR(7)
        XCTAssertEqual(manager.currentSeconds, 8, "diff ≤2 should keep internal counter")
        log.pass("8 then 7 → stays 8 (OCR within 2 s)")
    }

    func test_largeDrift_resyncs() {
        manager.resetForUnitTesting()
        manager.updateFromOCR(8)
        manager.updateFromOCR(3)
        XCTAssertEqual(manager.currentSeconds, 3)
        log.pass("8 then 3 → resync to 3")
    }

    func test_recommendation_follows_mapping() {
        manager.resetForUnitTesting()
        manager.updateFromOCR(15)
        if case .safeToCross(15) = manager.recommendation {
            log.pass("15 s → safeToCross recommendation")
        } else {
            log.fail("got \(manager.recommendation)")
            XCTFail()
        }
    }

    func test_signalNotDetected_resetsAfterTimeout() async throws {
        manager.resetForUnitTesting()
        manager.updateFromOCR(5)
        try await Task.sleep(nanoseconds: 3_500_000_000)
        manager.signalNotDetected()
        XCTAssertNil(manager.currentSeconds)
        XCTAssertEqual(manager.recommendation, .unknown)
        log.pass("signalNotDetected after 3.5s → nil seconds, unknown rec")
    }

    func test_reset_clearsState() {
        manager.resetForUnitTesting()
        manager.updateFromOCR(4)
        manager.resetForUnitTesting()
        XCTAssertNil(manager.currentSeconds)
        XCTAssertEqual(manager.recommendation, .unknown)
        log.pass("resetForUnitTesting → nil seconds, unknown")
    }
}
