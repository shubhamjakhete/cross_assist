//
//  LeftPanelView.swift
//  CrossAssist
//

import Combine
import SwiftUI

/// Unified state for Card 2 — merges pedestrianSignal model results (which
/// have priority) with the HSV-based TrafficLightState from yolo11n detections.
private enum TrafficCardState: Equatable {
    case red, yellow, green, walk, unknown
}

struct LeftPanelView: View {
    let trackedObjects: [TrackedObject]

    // MARK: - Live computed values (change every detection frame)

    private var nearestPerson: TrackedObject? {
        trackedObjects
            .filter { $0.label == "person" }
            .min(by: { ($0.distanceMeters ?? 99) < ($1.distanceMeters ?? 99) })
    }

    private var trafficLight: TrackedObject? {
        trackedObjects.first { $0.label == "traffic light" }
    }

    /// Count of all hazardous road objects: vehicles, bicycles, and path obstacles.
    private var dangerCount: Int {
        trackedObjects.filter {
            $0.label == "vehicle" || $0.label == "bicycle" || $0.label == "obstacle"
        }.count
    }

    /// pedestrianSignal model results take priority over HSV classification.
    private var liveTrafficState: TrafficCardState {
        if trackedObjects.contains(where: { $0.label == "WALK SIGNAL" }) { return .walk }
        if trackedObjects.contains(where: { $0.label == "GREEN LIGHT" }) { return .green }
        if trackedObjects.contains(where: { $0.label == "RED LIGHT"  }) { return .red }
        if trackedObjects.contains(where: { $0.label == "SIGNAL"     }) { return .unknown }
        switch trafficLight?.trafficLightState?.color {
        case .red:    return .red
        case .yellow: return .yellow
        case .green:  return .green
        default:      return .unknown
        }
    }

    /// Best walk-signal countdown recommendation across all tracked signal objects.
    private var activeSignalRec: WalkSignalRecommendation? {
        trackedObjects
            .compactMap { $0.walkSignalRecommendation }
            .filter { $0 != .unknown }
            .max(by: { $0.urgency < $1.urgency })
    }

    // MARK: - Debounced displayed state (what the cards actually show)

    @State private var displayedPersonDistance: String = "--"
    @State private var displayedPersonIsClose: Bool = false
    @State private var displayedTrafficState: TrafficCardState = .unknown
    @State private var displayedDangerCount: Int = 0
    @State private var displayedSignalRec: WalkSignalRecommendation? = nil

    // Pending values + per-field debounce clocks
    @State private var pendingPersonDistance: String = "--"
    @State private var pendingPersonIsClose: Bool = false
    @State private var pendingPersonTime: Date = Date()

    @State private var pendingTrafficState: TrafficCardState = .unknown
    @State private var pendingTrafficTime: Date = Date()

    @State private var pendingDangerCount: Int = 0
    @State private var pendingDangerTime: Date = Date()

    @State private var pendingSignalRec: WalkSignalRecommendation? = nil
    @State private var pendingSignalTime: Date = Date()

    private let debounceInterval: TimeInterval = 0.3
    private let panelTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // Pulse animations — driven from the debounced values so they don't
    // throb on every detection frame.
    @State private var dangerPulse = false
    @State private var countdownPulse = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            personCard
            trafficLightCard
            dangerCard
        }
        .padding(.top, 40)
        // Watch live values, update pending + reset per-field clock on change
        .onChange(of: nearestPerson?.formattedDistance ?? "--") { _, newDist in
            let isClose = (nearestPerson?.distanceMeters ?? 99) < 2.0
            if newDist != displayedPersonDistance || isClose != displayedPersonIsClose {
                pendingPersonDistance = newDist
                pendingPersonIsClose  = isClose
                pendingPersonTime     = Date()
            }
        }
        .onChange(of: liveTrafficState) { _, newState in
            if newState != displayedTrafficState {
                pendingTrafficState = newState
                pendingTrafficTime  = Date()
            }
        }
        .onChange(of: dangerCount) { _, newCount in
            if newCount != displayedDangerCount {
                pendingDangerCount = newCount
                pendingDangerTime  = Date()
            }
        }
        .onChange(of: activeSignalRec) { _, newRec in
            if newRec != displayedSignalRec {
                pendingSignalRec  = newRec
                pendingSignalTime = Date()
            }
        }
        // Commit pending values once each has been stable for debounceInterval
        .onReceive(panelTimer) { _ in
            let now = Date()
            if (pendingPersonDistance != displayedPersonDistance ||
                pendingPersonIsClose  != displayedPersonIsClose) &&
               now.timeIntervalSince(pendingPersonTime) >= debounceInterval {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedPersonDistance = pendingPersonDistance
                    displayedPersonIsClose  = pendingPersonIsClose
                }
            }
            if pendingTrafficState != displayedTrafficState &&
               now.timeIntervalSince(pendingTrafficTime) >= debounceInterval {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedTrafficState = pendingTrafficState
                }
            }
            if pendingDangerCount != displayedDangerCount &&
               now.timeIntervalSince(pendingDangerTime) >= debounceInterval {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedDangerCount = pendingDangerCount
                }
            }
            if pendingSignalRec != displayedSignalRec &&
               now.timeIntervalSince(pendingSignalTime) >= debounceInterval {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedSignalRec = pendingSignalRec
                }
            }
        }
        // Drive danger pulse from the debounced count
        .onChange(of: displayedDangerCount) { _, newCount in
            if newCount > 0 {
                dangerPulse = false
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    dangerPulse = true
                }
            } else {
                dangerPulse = false
            }
        }
        // Drive countdown pulse for high-urgency signal states
        .onChange(of: displayedSignalRec) { _, newRec in
            if (newRec?.urgency ?? -1) >= 2 {
                countdownPulse = false
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    countdownPulse = true
                }
            } else {
                withAnimation { countdownPulse = false }
            }
        }
    }

    // MARK: - Cards (use displayed/debounced values)

    private var personCard: some View {
        let iconColor: Color = displayedPersonIsClose
            ? Color(hex: "EF4444")
            : Color(hex: "3B82F6")

        return cardBase(background: Color.black.opacity(0.65)) {
            Image(systemName: "figure.walk")
                .font(.system(size: 22))
                .foregroundStyle(iconColor)
            Text(displayedPersonDistance)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    /// Card 2 — shows countdown OCR result when available; falls back to
    /// label-based colour state otherwise.
    @ViewBuilder private var trafficLightCard: some View {
        if let rec = displayedSignalRec, rec != .unknown {
            signalCountdownCard(for: rec)
        } else {
            labelBasedTrafficCard
        }
    }

    /// Countdown-aware card driven by `WalkSignalRecommendation`.
    @ViewBuilder private func signalCountdownCard(
        for rec: WalkSignalRecommendation
    ) -> some View {
        let bg = Color(hex: rec.colorHex).opacity(0.85)
        switch rec {
        case .safeToCross(let s):
            cardBase(background: bg) {
                Text("\(s)")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("sec left")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                Text("CROSS NOW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        case .hurry(let s):
            cardBase(background: bg) {
                Text("\(s)")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .scaleEffect(countdownPulse ? 1.05 : 1.0)
                Text("sec left")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                Text("HURRY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        case .tooLate(let s):
            cardBase(background: bg) {
                Text("\(s)")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .scaleEffect(countdownPulse ? 1.05 : 1.0)
                Text("sec left")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                Text("WAIT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        case .waitForNext:
            cardBase(background: bg) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .scaleEffect(countdownPulse ? 1.05 : 1.0)
                Text("WAIT")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("next signal")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
        case .safeNoCountdown:
            cardBase(background: bg) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                Text("WALK")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        case .unknown:
            labelBasedTrafficCard
        }
    }

    /// Fallback card — driven by label/HSV colour state when no OCR result is available.
    @ViewBuilder private var labelBasedTrafficCard: some View {
        switch displayedTrafficState {
        case .red:
            cardBase(background: Color(hex: "1A0000")) {
                Circle()
                    .fill(Color(hex: "EF4444"))
                    .frame(width: 28, height: 28)
                Text("WAIT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "EF4444"))
                    .lineLimit(1)
            }
        case .yellow:
            cardBase(background: Color(hex: "1A1200")) {
                Circle()
                    .fill(Color(hex: "EAB308"))
                    .frame(width: 28, height: 28)
                Text("SLOW")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "EAB308"))
                    .lineLimit(1)
            }
        case .green:
            cardBase(background: Color(hex: "001A08")) {
                Circle()
                    .fill(Color(hex: "22C55E"))
                    .frame(width: 28, height: 28)
                Text("SAFE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "22C55E"))
                    .lineLimit(1)
            }
        case .walk:
            cardBase(background: Color(hex: "001626")) {
                Circle()
                    .fill(Color(hex: "3B82F6"))
                    .frame(width: 28, height: 28)
                Text("WALK")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "3B82F6"))
                    .lineLimit(1)
            }
        case .unknown:
            cardBase(background: Color.black.opacity(0.65)) {
                Image(systemName: "stoplights")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                Text("UNKNOWN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                    .lineLimit(1)
            }
        }
    }

    private var dangerCard: some View {
        let bg: Color = displayedDangerCount > 0
            ? (dangerPulse ? Color.red.opacity(0.3) : Color.black.opacity(0.65))
            : Color.black.opacity(0.65)

        return cardBase(background: bg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: "EF4444"))
            Text("\(displayedDangerCount)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    // MARK: - Card base

    @ViewBuilder
    private func cardBase<Content: View>(
        background: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 5) {
            content()
        }
        .frame(width: 76, height: 76)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        HStack {
            LeftPanelView(trackedObjects: [
                TrackedObject(id: 0, label: "person", confidence: 0.9,
                              boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.15, height: 0.50),
                              distanceMeters: 1.3),
                TrackedObject(id: 1, label: "car", confidence: 0.85,
                              boundingBox: CGRect(x: 0.4, y: 0.3, width: 0.35, height: 0.55),
                              distanceMeters: 0.7),
                TrackedObject(id: 2, label: "traffic light", confidence: 0.78,
                              boundingBox: CGRect(x: 0.6, y: 0.1, width: 0.08, height: 0.20),
                              distanceMeters: 8.0),
            ])
            .padding(.leading, 16)
            Spacer()
        }
    }
}
