//
//  BottomStatusBar.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import Combine
import SwiftUI

struct BottomStatusBar: View {
    let trackedObjects: [TrackedObject]

    @State private var lastObjectSeen: Date = Date()
    @State private var now: Date = Date()

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // MARK: - Status computation

    private var statusInfo: (text: String, color: Color) {
        // 1. Obstacle under 0.8 m — highest priority
        let hasObstacle = trackedObjects.contains { obj in
            (DistanceEstimator.estimate(boundingBox: obj.boundingBox, label: obj.label) ?? 99) < 0.8
        }
        if hasObstacle {
            return ("⚠ OBSTACLE — STOP", Color(hex: "EF4444"))
        }

        // 2. Zebra / crossing label
        let hasCrossing = trackedObjects.contains {
            $0.label.lowercased().contains("zebra") || $0.label.lowercased().contains("crossing")
        }
        if hasCrossing {
            return ("ZEBRA CROSSING DETECTED", Color(hex: "3B82F6"))
        }

        // 3. No detections for > 3 seconds
        if trackedObjects.isEmpty && now.timeIntervalSince(lastObjectSeen) > 3 {
            return ("Searching...", Color(hex: "9CA3AF"))
        }

        // 4. Default
        return ("Path clear ✓", Color(hex: "22C55E"))
    }

    // MARK: - Body

    var body: some View {
        Text(statusInfo.text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(statusInfo.color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.65), in: Capsule())
            .onReceive(timer) { date in
                now = date
            }
            .onChange(of: trackedObjects.count) { _, count in
                if count > 0 { lastObjectSeen = Date() }
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
