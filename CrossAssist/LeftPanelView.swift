//
//  LeftPanelView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

struct LeftPanelView: View {
    let trackedObjects: [TrackedObject]
    @State private var dangerPulse = false

    // MARK: - Computed properties

    private var nearestPersonDistance: Float? {
        trackedObjects
            .filter { $0.label == "person" }
            .compactMap { DistanceEstimator.estimate(boundingBox: $0.boundingBox, label: $0.label) }
            .min()
    }

    private var dangerCount: Int {
        trackedObjects.filter { obj in
            guard let d = DistanceEstimator.estimate(boundingBox: obj.boundingBox, label: obj.label)
            else { return false }
            return d < 1.5
        }.count
    }

    // MARK: - Body

    var body: some View {
        // FIX 3: padding(.top, 40) + 80pt spacer in MainDetectionView = 120pt from top
        VStack(spacing: 10) {
            personCard
            trafficLightCard
            dangerCard
        }
        .padding(.top, 40)
        .onChange(of: dangerCount) { _, newCount in
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

    // MARK: - Cards

    private var personCard: some View {
        let isClose = (nearestPersonDistance ?? 99) < 2
        let iconColor: Color = isClose ? Color(hex: "EF4444") : Color(hex: "3B82F6")
        let distText = nearestPersonDistance.map { String(format: "%.1fm", $0) } ?? "--"

        return cardBase(background: Color.black.opacity(0.65)) {
            Image(systemName: "figure.walk")
                .font(.system(size: 22))
                .foregroundStyle(iconColor)
            Text(distText)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var trafficLightCard: some View {
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

    private var dangerCard: some View {
        let bg: Color = dangerCount > 0
            ? (dangerPulse ? Color.red.opacity(0.3) : Color.black.opacity(0.65))
            : Color.black.opacity(0.65)

        return cardBase(background: bg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: "EF4444"))
            Text("\(dangerCount)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    // MARK: - Helper

    // FIX 1: explicit background + clipShape ensures rounded corners clip content correctly
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
                              boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.15, height: 0.50)),
                TrackedObject(id: 1, label: "car", confidence: 0.85,
                              boundingBox: CGRect(x: 0.4, y: 0.3, width: 0.35, height: 0.55)),
            ])
            .padding(.leading, 16)
            Spacer()
        }
    }
}
