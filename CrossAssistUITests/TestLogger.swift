//
//  TestLogger.swift
//  CrossAssistUITests
//

import Foundation

/// Shared structured logging for UI / accessibility tests (same format as unit tests).
final class TestLogger {

    private let suiteTitle: String
    private(set) var passCount = 0
    private(set) var failCount = 0
    private(set) var warnCount = 0

    init(suiteTitle: String) {
        self.suiteTitle = suiteTitle
    }

    func printSuiteHeader() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(suiteTitle)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    private static func fileName(_ file: StaticString) -> String {
        URL(fileURLWithPath: "\(file)", isDirectory: false).lastPathComponent
    }

    func pass(file: StaticString = #file, line: UInt = #line, _ message: String) {
        passCount += 1
        print("✅ PASS | \(Self.fileName(file)):\(line) | \(message)")
    }

    func fail(file: StaticString = #file, line: UInt = #line, _ message: String) {
        failCount += 1
        print("❌ FAIL | \(Self.fileName(file)):\(line) | \(message)")
    }

    func warn(file: StaticString = #file, line: UInt = #line, _ message: String) {
        warnCount += 1
        print("⚠️  WARN | \(Self.fileName(file)):\(line) | \(message)")
    }

    func info(file: StaticString = #file, line: UInt = #line, _ message: String) {
        print("ℹ️  INFO | \(Self.fileName(file)):\(line) | \(message)")
    }

    func printSuiteSummary() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("TEST SUMMARY — \(suiteTitle)")
        print("✅ Passed:   \(passCount)")
        print("❌ Failed:   \(failCount)")
        print("⚠️  Warnings: \(warnCount)")
        print("Total:      \(passCount + failCount + warnCount)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    func resetCounts() {
        passCount = 0
        failCount = 0
        warnCount = 0
    }
}
