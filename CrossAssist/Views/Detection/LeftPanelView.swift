//
//  LeftPanelView.swift
//  CrossAssist
//

import Combine
import SwiftUI

/// Unified state for Card 2 — merges pedestrianSignal model results (which
/// have priority) with the HSV-based TrafficLightState from yolo11n detections.
private enum TrafficCardState: Equatable {
    case red, yellow, green, walk, crosswalk, unknown
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

    /// Live distance text for the nearest detected crosswalk (or "" if none).
    private var nearestCrosswalkDistance: String {
        trackedObjects.first { $0.label == "CROSSWALK" }?.formattedDistance ?? ""
    }

    /// Priority order: crosswalk model > pedestrianSignal model > HSV colour.
    private var liveTrafficState: TrafficCardState {
        if trackedObjects.contains(where: { $0.label == "CROSSWALK"   }) { return .crosswalk }
        // pedestrianSignal labels: RED LIGHT checked before WALK SIGNAL so a red
        // signal is never overridden by a concurrent .safeNoCountdown rec.
        if trackedObjects.contains(where: { $0.label == "RED LIGHT"  }) { return .red }
        if trackedObjects.contains(where: { $0.label == "WALK SIGNAL" }) { return .walk }
        if trackedObjects.contains(where: { $0.label == "GREEN LIGHT" }) { return .green }
        if trackedObjects.contains(where: { $0.label == "SIGNAL"     }) { return .unknown }
        switch trafficLight?.trafficLightState?.color {
        case .red:    return .red
        case .yellow: return .yellow
        // Vehicle green ≠ pedestrian safe to cross — show SLOW (yellow card)
        // so the user waits for the walk signal before stepping off the kerb.
        case .green:  return .yellow
        default:      return .unknown
        }
    }

    // MARK: - Debounced displayed state (what the cards actually show)

    @State private var displayedPersonDistance: String = "--"
    @State private var displayedPersonIsClose: Bool = false
    @State private var displayedTrafficState: TrafficCardState = .unknown
    @State private var displayedDangerCount: Int = 0

    // Pending values + per-field debounce clocks
    @State private var pendingPersonDistance: String = "--"
    @State private var pendingPersonIsClose: Bool = false
    @State private var pendingPersonTime: Date = Date()

    @State private var pendingTrafficState: TrafficCardState = .unknown
    @State private var pendingTrafficTime: Date = Date()

    @State private var pendingDangerCount: Int = 0
    @State private var pendingDangerTime: Date = Date()

    private let debounceInterval: TimeInterval = 0.3
    private let panelTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // Pulse animation — driven from the debounced danger count.
    @State private var dangerPulse = false

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

    /// Card 2 — driven entirely by the pedestrianSignal model label and HSV
    /// traffic-light colour.  Timer countdown data is now displayed exclusively
    /// in CrossingGuidanceView which auto-presents when a timer is detected.
    @ViewBuilder private var trafficLightCard: some View {
        labelBasedTrafficCard
    }

    /// Card — driven by label/HSV colour state (pedestrianSignal model labels
    /// take priority over HSV vehicle-light classification).
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
        case .crosswalk:
            cardBase(background: Color(hex: "3B82F6")) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                Text("CROSSING")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !nearestCrosswalkDistance.isEmpty && nearestCrosswalkDistance != "--" {
                    Text(nearestCrosswalkDistance)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
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
