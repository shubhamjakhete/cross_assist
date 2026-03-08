//
//  TopBarView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI
import UIKit

struct TopBarView: View {
    @AppStorage("voiceEnabled")   private var voiceEnabled   = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var batteryLevel: Float = -1

    var onSOSTapped: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            // Voice toggle
            Button { voiceEnabled.toggle() } label: {
                pill(
                    icon: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    text: voiceEnabled ? "Voice ON"  : "Voice OFF"
                )
            }

            // Haptic toggle
            Button { hapticsEnabled.toggle() } label: {
                pill(
                    icon: hapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone",
                    text: hapticsEnabled ? "Haptic ON" : "Haptic OFF"
                )
            }

            // Battery (non-interactive)
            pill(
                icon: "battery.100",
                text: batteryLevel < 0 ? "100%" : "\(Int(batteryLevel * 100))%"
            )

            // SOS button
            Button { onSOSTapped() } label: {
                Text("SOS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "EF4444"), in: Capsule())
            }
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryLevel = UIDevice.current.batteryLevel
        }
    }

    private func pill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55), in: Capsule())
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        TopBarView(onSOSTapped: { print("SOS preview tapped") })
            .padding(.top, 12)
    }
}
