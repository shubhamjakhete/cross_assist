//
//  BottomStatusBar.swift
//  CrossAssist
//

import Combine
import SwiftUI

// MARK: - Status type

/// Typed representation of the bar's five priority tiers.
/// Associated values use pre-formatted strings so Equatable comparison
/// is quantized to the display resolution (e.g. "1.4m") rather than raw
/// Float, which prevents micro-jitter from blocking the debounce commit.
enum StatusType: Equatable {
    case critical(String, String)    // label, formattedDistance
    case dangerous(String, String)
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
        if let critical = trackedObjects.first(where: { $0.isCritical }) {
            return .critical(critical.label, critical.formattedDistance)
        }
        if let dangerous = trackedObjects
            .filter({ $0.isDangerous })
            .min(by: { ($0.distanceMeters ?? 99) < ($1.distanceMeters ?? 99) }) {
            return .dangerous(dangerous.label, dangerous.formattedDistance)
        }
        if trackedObjects.contains(where: {
            $0.label.lowercased().contains("zebra") ||
            $0.label.lowercased().contains("crossing")
        }) {
            return .zebra
        }
        if trackedObjects.isEmpty {
            return .scanning
        }
        return .clear
    }

    // MARK: - Display helper

    private var statusInfo: (text: String, color: Color) {
        switch displayedStatus {
        case .critical(let label, let dist):
            return ("⚠ STOP — \(label.uppercased()) at \(dist)", Color(hex: "EF4444"))
        case .dangerous(let label, let dist):
            return ("⚠ \(label.uppercased()) nearby — \(dist)", Color(hex: "F97316"))
        case .zebra:
            return ("ZEBRA CROSSING DETECTED", Color(hex: "3B82F6"))
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
        case (.critical,  .critical):  return true
        case (.dangerous, .dangerous): return true
        case (.zebra,     .zebra):     return true
        case (.scanning,  .scanning):  return true
        case (.clear,     .clear):     return true
        default:                       return false
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
