//
//  BottomStatusBar.swift
//  CrossAssist
//

import Combine
import SwiftUI

// MARK: - Status type

/// Typed representation of the bar's priority tiers.
/// Associated values use pre-formatted strings so Equatable comparison is
/// quantized to display resolution (e.g. "1.4m") rather than raw Float,
/// preventing micro-jitter from blocking the debounce commit.
enum StatusType: Equatable {
    case critical(String, String)    // label, formattedDistance
    case timerTooLate(Int)           // seconds remaining
    case timerWaitForNext
    case timerHurry(Int)             // seconds remaining
    case timerSafeToCross(Int)       // seconds remaining
    case dangerous(String, String)
    case timerSafeNoCountdown
    case zebra
    case scanning
    case clear
}

// MARK: - View

struct BottomStatusBar: View {
    let trackedObjects: [TrackedObject]

    // Displayed (stable, debounced) status
    @State private var displayedStatus: StatusType = .clear

    // Pending status and when it was first seen
    @State private var pendingStatus: StatusType = .clear
    @State private var pendingStartTime: Date = Date()

    private let debounceInterval: TimeInterval = 0.5
    private let fastTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // MARK: - Live status (recomputed every render)

    var currentStatus: StatusType {
        // 1. Physical proximity — always highest priority.
        if let critical = trackedObjects.first(where: { $0.isCritical }) {
            return .critical(critical.label, critical.formattedDistance)
        }

        // Compute best walk-signal recommendation once for tiers 2–5 & 7.
        let timerRec = trackedObjects
            .compactMap { $0.walkSignalRecommendation }
            .filter { $0 != .unknown }
            .max(by: { $0.urgency < $1.urgency })

        // 2–5. Timer-based signal priorities.
        if let rec = timerRec {
            switch rec {
            case .tooLate(let s):     return .timerTooLate(s)
            case .waitForNext:        return .timerWaitForNext
            case .hurry(let s):       return .timerHurry(s)
            case .safeToCross(let s): return .timerSafeToCross(s)
            default: break
            }
        }

        // 6. Dangerous proximity.
        if let dangerous = trackedObjects
            .filter({ $0.isDangerous })
            .min(by: { ($0.distanceMeters ?? 99) < ($1.distanceMeters ?? 99) }) {
            return .dangerous(dangerous.label, dangerous.formattedDistance)
        }

        // 7. Solid WALK figure (no countdown visible).
        if timerRec == .safeNoCountdown { return .timerSafeNoCountdown }

        // 8. Zebra / crosswalk detected.
        if trackedObjects.contains(where: {
            $0.label.lowercased().contains("zebra") ||
            $0.label.lowercased().contains("crossing")
        }) {
            return .zebra
        }

        // 9. Nothing detected yet.
        if trackedObjects.isEmpty { return .scanning }

        // 10. Default — scene has objects but no hazards.
        return .clear
    }

    // MARK: - Display helper

    private var statusInfo: (text: String, color: Color) {
        switch displayedStatus {
        case .critical(let label, let dist):
            return ("⚠ STOP — \(label.uppercased()) at \(dist)", Color(hex: "EF4444"))
        case .timerTooLate(let s):
            return ("⚠ Too late • \(s)s — wait for next", Color(hex: "EF4444"))
        case .timerWaitForNext:
            return ("⚠ Wait for next signal", Color(hex: "EF4444"))
        case .timerHurry(let s):
            return ("HURRY • \(s)s left to cross", Color(hex: "F97316"))
        case .timerSafeToCross(let s):
            return ("✓ Cross now • \(s)s remaining", Color(hex: "22C55E"))
        case .dangerous(let label, let dist):
            return ("⚠ \(label.uppercased()) nearby — \(dist)", Color(hex: "F97316"))
        case .timerSafeNoCountdown:
            return ("Safe to cross ✓", Color(hex: "22C55E"))
        case .zebra:
            return ("CROSSWALK DETECTED", Color(hex: "3B82F6"))
        case .scanning:
            return ("Scanning...", Color(hex: "9CA3AF"))
        case .clear:
            return ("Path clear ✓", Color(hex: "22C55E"))
        }
    }

    // MARK: - Body

    var body: some View {
        Text(statusInfo.text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(statusInfo.color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.65), in: Capsule())
            .animation(.easeInOut(duration: 0.3), value: displayedStatus)
            // Watch the live status. Only reset the debounce clock when the
            // STATUS CATEGORY changes — not when distance jitters within the
            // same category (e.g. critical at 1.4m → 1.5m). This prevents
            // distance micro-changes from blocking the commit timer.
            .onChange(of: currentStatus) { _, newStatus in
                guard newStatus != displayedStatus else { return }
                if !sameCategory(newStatus, pendingStatus) {
                    pendingStartTime = Date()
                }
                pendingStatus = newStatus
            }
            // Commit pending → displayed once it has been stable long enough
            .onReceive(fastTimer) { _ in
                guard pendingStatus != displayedStatus else { return }
                if Date().timeIntervalSince(pendingStartTime) >= debounceInterval {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        displayedStatus = pendingStatus
                    }
                }
            }
    }

    // MARK: - Helpers

    /// Returns true when two StatusType values belong to the same category,
    /// ignoring their associated values (e.g. label / distance).
    private func sameCategory(_ a: StatusType, _ b: StatusType) -> Bool {
        switch (a, b) {
        case (.critical,             .critical):             return true
        case (.timerTooLate,         .timerTooLate):         return true
        case (.timerWaitForNext,     .timerWaitForNext):     return true
        case (.timerHurry,           .timerHurry):           return true
        case (.timerSafeToCross,     .timerSafeToCross):     return true
        case (.dangerous,            .dangerous):            return true
        case (.timerSafeNoCountdown, .timerSafeNoCountdown): return true
        case (.zebra,                .zebra):                return true
        case (.scanning,             .scanning):             return true
        case (.clear,                .clear):                return true
        default:                                             return false
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        VStack {
            Spacer()
            BottomStatusBar(trackedObjects: [])
                .padding(.bottom, 90)
        }
    }
}
