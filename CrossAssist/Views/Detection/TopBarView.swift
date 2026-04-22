//
//  TopBarView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI
import UIKit

struct TopBarView: View {
    @AppStorage("voiceEnabled") private var voiceEnabled = true
    @State private var batteryLevel: Float = -1

    var onSOSTapped: () -> Void = {}

    var body: some View {
        HStack {
            // Voice toggle — left
            Button {
                voiceEnabled.toggle()
                if !voiceEnabled {
                    VoiceAnnouncementService.shared.stopAll()
                }
            } label: {
                pill(
                    icon: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    text: voiceEnabled ? "Voice ON" : "Voice OFF"
                )
            }

            Spacer()

            // SOS — center
            Button { onSOSTapped() } label: {
                Text("SOS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "EF4444"), in: Capsule())
            }

            Spacer()

            // Battery — right
            pill(
                icon: "battery.100",
                text: batteryLevel < 0 ? "100%" : "\(Int(batteryLevel * 100))%"
            )
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryLevel = UIDevice.current.batteryLevel
        }
    }

    private func pill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
