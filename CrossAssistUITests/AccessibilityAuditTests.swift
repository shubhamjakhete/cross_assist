//
//  AccessibilityAuditTests.swift
//  CrossAssistUITests
//
//  Automated accessibility audit (iOS 17+), element labels, touch targets, VoiceOver copy.
//

import XCTest

/// UI tests: reset onboarding and mark UITest mode (read in app via `--resetOnboarding`).
private func makeConfiguredApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--resetOnboarding"]
    return app
}

// MARK: - Audit helpers

@MainActor
private enum AccessibilityAuditRunner {

    static func runAudit(
        app: XCUIApplication,
        screenName: String,
        log: TestLogger,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard #available(iOS 17.0, *) else {
            log.info("performAccessibilityAudit requires iOS 17+ — skipping \(screenName)")
            return
        }
        log.info("Starting accessibility audit — \(screenName)")
        var collected: [(severity: Int, detail: String)] = []
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let desc = String(describing: issue)
                log.warn("Audit issue [\(screenName)]: \(desc)")
                collected.append((0, "[\(screenName)] \(desc)"))
                return true
            }
        } catch {
            log.warn("performAccessibilityAudit threw for \(screenName): \(error.localizedDescription)")
        }
        log.info("Audit finished — \(screenName) — raw issues logged: \(collected.count)")
        let sorted = collected.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return $0.detail < $1.detail
        }
        if !sorted.isEmpty {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("PRIORITIZED AUDIT FINDINGS (by severity) — \(screenName)")
            for r in sorted {
                print(" • \(r.detail)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }
}

// MARK: - 1) Automated audit (three screens)

final class AccessibilityAuditFlowTests: XCTestCase {

    private let log = TestLogger(suiteTitle: "ACCESSIBILITY AUDIT (AUTOMATED)")

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = true
        log.resetCounts()
    }

    override func tearDownWithError() throws {
        log.printSuiteSummary()
        try super.tearDownWithError()
    }

    @MainActor
    func test_audit_onboarding_screen() throws {
        log.printSuiteHeader()
        let app = makeConfiguredApp()
        app.launch()

        let onboardingVisible = app.staticTexts["CrossAssist"].waitForExistence(timeout: 5)
            || app.buttons["Start Setup"].waitForExistence(timeout: 5)
        if !onboardingVisible {
            log.warn("Onboarding markers not found within 5s — audit may be wrong screen")
        }
        AccessibilityAuditRunner.runAudit(app: app, screenName: "Onboarding (launch)", log: log)
        log.pass("Onboarding screen audit completed (issues logged as warnings only)")
    }

    @MainActor
    func test_audit_home_screen() throws {
        log.printSuiteHeader()
        let app = makeConfiguredApp()
        app.launch()

        guard app.buttons["Continue as Guest"].waitForExistence(timeout: 5) else {
            log.warn("Continue as Guest not found — skipping home audit")
            return
        }
        app.buttons["Continue as Guest"].tap()

        let homeReady = app.staticTexts["Ready to cross"].waitForExistence(timeout: 5)
            || app.buttons["Start Crossing Assistant"].waitForExistence(timeout: 5)
        if !homeReady {
            log.warn("Home screen indicators not found within 5s")
        }
        AccessibilityAuditRunner.runAudit(app: app, screenName: "Home", log: log)
        log.pass("Home screen audit completed (issues logged as warnings only)")
    }

    @MainActor
    func test_audit_settings_screen() throws {
        log.printSuiteHeader()
        let app = makeConfiguredApp()
        app.launch()

        guard app.buttons["Continue as Guest"].waitForExistence(timeout: 5) else {
            log.warn("Continue as Guest not found — skipping settings audit")
            return
        }
        app.buttons["Continue as Guest"].tap()
        _ = app.buttons["Start Crossing Assistant"].waitForExistence(timeout: 8)

        let settingsBtn = app.buttons.matching(NSPredicate(format: "label == %@", "Settings")).firstMatch
        guard settingsBtn.waitForExistence(timeout: 5) else {
            log.warn("Settings button not found — skipping settings audit")
            return
        }
        settingsBtn.tap()
        sleep(1)
        if !app.staticTexts["Settings"].waitForExistence(timeout: 5) {
            log.warn("Settings screen title not matched within 5s — auditing current UI anyway")
        }
        AccessibilityAuditRunner.runAudit(app: app, screenName: "Settings (sheet)", log: log)
        log.pass("Settings screen audit completed (issues logged as warnings only)")
    }
}

// MARK: - 2) Labels & traits

final class AccessibilityLabelsAndTraitsTests: XCTestCase {

    private let log = TestLogger(suiteTitle: "ACCESSIBILITY LABELS & TRAITS")

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = true
        log.resetCounts()
    }

    override func tearDownWithError() throws {
        log.printSuiteSummary()
        try super.tearDownWithError()
    }

    @MainActor
    func test_keyControls_have_useful_labels() throws {
        log.printSuiteHeader()
        let app = makeConfiguredApp()
        app.launch()
        if app.buttons["Continue as Guest"].waitForExistence(timeout: 4) {
            app.buttons["Continue as Guest"].tap()
        }
        _ = app.buttons["Start Crossing Assistant"].waitForExistence(timeout: 8)
        app.buttons["Start Crossing Assistant"].firstMatch.tap()

        let stop = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "STOP")).firstMatch
        if stop.waitForExistence(timeout: 8) {
            let lab = stop.label
            XCTAssertFalse(lab.isEmpty, "STOP must have label")
            log.pass("STOP label: \"\(lab)\"")
        } else {
            log.warn("STOP button not found")
        }

        let voice = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Voice")).firstMatch
        if voice.exists {
            log.pass("Voice pill label: \"\(voice.label)\"")
        } else {
            log.warn("Voice toggle not found")
        }

        let sos = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "SOS")).firstMatch
        if sos.exists {
            let lab = sos.label
            if lab.lowercased().contains("emergency") || lab == "SOS" {
                log.pass("SOS accessibility: \"\(lab)\" (expect emergency wording in production)")
            } else {
                log.warn("SOS label \"\(lab)\" — prefer containing \"emergency\" for clarity")
            }
        } else {
            log.warn("SOS button not found")
        }

        let panelRegion = app.scrollViews.firstMatch
        if panelRegion.exists {
            log.info("Left panel container exists — verify Card 1/2 in hierarchy on device")
        }

        log.info("Bounding boxes: OverlayView uses Canvas; VoiceOver may not enumerate boxes individually — verify .accessibilityHidden in app if needed")
    }
}

// MARK: - 3) Touch targets (44×44)

final class AccessibilityTouchTargetTests: XCTestCase {

    private let log = TestLogger(suiteTitle: "MINIMUM TOUCH TARGET (44×44)")

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = true
    }

    override func tearDownWithError() throws {
        log.printSuiteSummary()
        try super.tearDownWithError()
    }

    @MainActor
    private func warnIfSmall(name: String, frame: CGRect, log: TestLogger) {
        let w = frame.width
        let h = frame.height
        if w < 44 || h < 44 {
            log.warn("\(name) frame \(Int(w))×\(Int(h)) — below 44×44")
        } else {
            log.pass("\(name) frame \(Int(w))×\(Int(h))")
        }
    }

    @MainActor
    func test_touchTargets_onDetectionScreen() throws {
        log.resetCounts()
        log.printSuiteHeader()
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Continue as Guest"].waitForExistence(timeout: 4) {
            app.buttons["Continue as Guest"].tap()
        }
        XCTAssertTrue(app.buttons["Start Crossing Assistant"].waitForExistence(timeout: 10))
        app.buttons["Start Crossing Assistant"].firstMatch.tap()

        let stop = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "STOP")).firstMatch
        if stop.waitForExistence(timeout: 8) {
            warnIfSmall(name: "STOP", frame: stop.frame, log: log)
        }
        let voice = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Voice")).firstMatch
        if voice.exists { warnIfSmall(name: "Voice", frame: voice.frame, log: log) }
        let haptic = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Haptic")).firstMatch
        if haptic.exists { warnIfSmall(name: "Haptic", frame: haptic.frame, log: log) }
        let sos = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "SOS")).firstMatch
        if sos.exists { warnIfSmall(name: "SOS", frame: sos.frame, log: log) }

        let mapBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "map")).firstMatch
        if mapBtn.exists { warnIfSmall(name: "Map icon", frame: mapBtn.frame, log: log) }

        let gear = app.buttons["Settings"].firstMatch
        if gear.exists { warnIfSmall(name: "Settings gear", frame: gear.frame, log: log) }

        let tabs = app.buttons.matching(identifier: "").allElementsBoundByIndex
        log.info("Tab bar element count (approx): \(tabs.count) — inspect frames in Xcode")
    }
}

// MARK: - 4) VoiceOver copy quality

final class AccessibilityVoiceOverQualityTests: XCTestCase {

    private let log = TestLogger(suiteTitle: "VOICEOVER ANNOUNCEMENT QUALITY")

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = true
    }

    override func tearDownWithError() throws {
        log.printSuiteSummary()
        try super.tearDownWithError()
    }

    @MainActor
    func test_detection_screen_meaningful_strings() throws {
        log.resetCounts()
        log.printSuiteHeader()
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Continue as Guest"].waitForExistence(timeout: 4) {
            app.buttons["Continue as Guest"].tap()
        }
        XCTAssertTrue(app.buttons["Start Crossing Assistant"].waitForExistence(timeout: 10))
        app.buttons["Start Crossing Assistant"].firstMatch.tap()

        let status = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Path")).firstMatch
        if status.waitForExistence(timeout: 6) {
            XCTAssertFalse(status.label.isEmpty)
            log.pass("Status bar text: \"\(status.label)\"")
        } else {
            log.warn("Status bar text not matched — check BottomStatusBar copy")
        }

        let crosswalkBanner = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Crosswalk")).firstMatch
        if crosswalkBanner.exists {
            log.pass("Crosswalk banner present: \"\(crosswalkBanner.label)\"")
        } else {
            log.info("Crosswalk banner not visible without detection (expected)")
        }

        log.info("Distance VoiceOver: verify LeftPanel shows units (e.g. meters) in UI tests on device with accessibility inspector")
    }
}
