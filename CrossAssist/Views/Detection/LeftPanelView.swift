//
//  LeftPanelView.swift
//  CrossAssist
//

import Combine
import SwiftUI

struct LeftPanelView: View {
    let trackedObjects: [TrackedObject]

    // MARK: - Live computed values (change every detection frame)

    private var nearestPerson: TrackedObject? {
        trackedObjects
            .filter { $0.label.lowercased() == "person" }
            .min(by: { ($0.distanceMeters ?? 99) < ($1.distanceMeters ?? 99) })
    }

    private var trafficLight: TrackedObject? {
        trackedObjects.first { $0.label.lowercased().contains("traffic") }
    }

    private var dangerCount: Int {
        trackedObjects.filter { $0.isDangerous }.count
    }

    // MARK: - Debounced displayed state (what the cards actually show)

    @State private var displayedPersonDistance: String = "--"
    @State private var displayedPersonIsClose: Bool = false
    @State private var displayedTrafficLight: String = "UNKNOWN"
    @State private var displayedDangerCount: Int = 0

    // Pending values + per-field debounce clocks
    @State private var pendingPersonDistance: String = "--"
    @State private var pendingPersonIsClose: Bool = false
    @State private var pendingPersonTime: Date = Date()

    @State private var pendingTrafficLight: String = "UNKNOWN"
    @State private var pendingTrafficTime: Date = Date()

    @State private var pendingDangerCount: Int = 0
    @State private var pendingDangerTime: Date = Date()

    private let debounceInterval: TimeInterval = 0.3
    private let panelTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // Pulse animation driven by the debounced danger count
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
        .onChange(of: trafficLight != nil) { _, detected in
            let text = detected ? "DETECTED" : "UNKNOWN"
            if text != displayedTrafficLight {
                pendingTrafficLight = text
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
            if pendingTrafficLight != displayedTrafficLight &&
               now.timeIntervalSince(pendingTrafficTime) >= debounceInterval {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedTrafficLight = pendingTrafficLight
                }
            }
            if pendingDangerCount != displayedDangerCount &&
               now.timeIntervalSince(pendingDangerTime) >= debounceInterval {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedDangerCount = pendingDangerCount
                }
            }
        }
        // Drive pulse from the debounced count so it doesn't throb on every frame
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

    private var trafficLightCard: some View {
        let detected   = displayedTrafficLight == "DETECTED"
        let iconColor: Color = detected ? Color(hex: "EAB308") : Color(hex: "9CA3AF")
        let textColor: Color = detected ? Color(hex: "EAB308") : Color(hex: "9CA3AF")

        return cardBase(background: Color.black.opacity(0.65)) {
            Image(systemName: "stoplights")
                .font(.system(size: 22))
                .foregroundStyle(iconColor)
            Text(displayedTrafficLight)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(textColor)
                .lineLimit(1)
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
