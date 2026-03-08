//
//  AccessibilitySetupView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

struct AccessibilitySetupView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("voiceEnabled")          private var voiceEnabled    = true
    @AppStorage("hapticStrength")        private var hapticStrength: Double = 0.7
    @AppStorage("highContrastMode")      private var highContrast    = false
    @AppStorage("detectionSensitivity")  private var sensitivity     = "Normal"
    @AppStorage("onboardingComplete")    private var onboardingComplete = false

    @State private var showHome = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0A0F1E").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        titleSection
                        settingsCards
                        saveButton
                        Spacer().frame(height: 20)
                    }
                }

                tabBar
            }
        }
        .fullScreenCover(isPresented: $showHome) {
            HomeView()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text("Accessibility Setup")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button { print("help tapped") } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Configure Assistance")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Personalize your CrossAssist experience\nwith voice, haptic, and visual controls.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "9CA3AF"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    // MARK: - Settings Cards

    private var settingsCards: some View {
        VStack(spacing: 14) {
            voiceCard
            hapticCard
            contrastCard
            sensitivityCard
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }

    // CARD 1 — Voice Guidance
    private var voiceCard: some View {
        HStack(spacing: 14) {
            settingIcon("person.wave.2.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Guidance")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("Real-time audio navigation cues")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "9CA3AF"))
            }
            Spacer()
            Toggle("", isOn: $voiceEnabled)
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "2563EB")))
                .labelsHidden()
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
    }

    // CARD 2 — Haptic Strength
    private var hapticCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                settingIcon("iphone.radiowaves.left.and.right")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Haptic Strength")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Tactile vibration intensity")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                }
                Spacer()
            }

            VStack(spacing: 8) {
                Slider(value: $hapticStrength, in: 0...1)
                    .tint(Color(hex: "2563EB"))
                    .padding(.horizontal, 4)

                HStack {
                    Text("SOFT")
                    Spacer()
                    Text("MEDIUM")
                    Spacer()
                    Text("STRONG")
                }
                .font(.system(size: 11))
                .tracking(1)
                .foregroundStyle(Color(hex: "6B7280"))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
    }

    // CARD 3 — High Contrast Mode
    private var contrastCard: some View {
        HStack(spacing: 14) {
            settingIcon("circle.lefthalf.filled")
            VStack(alignment: .leading, spacing: 4) {
                Text("High Contrast Mode")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("Increase UI visibility")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "9CA3AF"))
            }
            Spacer()
            Toggle("", isOn: $highContrast)
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "2563EB")))
                .labelsHidden()
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
    }

    // CARD 4 — Detection Sensitivity
    private var sensitivityCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                settingIcon("dot.radiowaves.forward")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detection Sensitivity")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Object and crossing awareness")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                }
                Spacer()
            }

            HStack(spacing: 12) {
                ForEach(["Low", "Normal", "High"], id: \.self) { level in
                    Button { sensitivity = level } label: {
                        Text(level)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(sensitivity == level ? Color(hex: "2563EB") : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(sensitivity == level
                                          ? Color(hex: "1D3461")
                                          : Color(hex: "1F2937"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                sensitivity == level
                                                    ? Color(hex: "2563EB")
                                                    : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: 0) {
            Button { saveAndContinue() } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "2563EB"))
                    HStack(spacing: 10) {
                        Text("Save Configuration")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }

            Text("Settings are synced to your CrossAssist account")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "6B7280"))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "house.fill",       label: "HOME",     selected: false)
            tabItem(icon: "location.north",   label: "NAVIGATE", selected: false)
            tabItem(icon: "gearshape.fill",   label: "SETTINGS", selected: true)
            tabItem(icon: "person.fill",      label: "PROFILE",  selected: false)
        }
        .padding(.vertical, 12)
        .background(
            Color(hex: "0A0F1E")
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }
        )
    }

    private func tabItem(icon: String, label: String, selected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(selected ? Color(hex: "2563EB") : Color.white.opacity(0.35))
            Text(label)
                .font(.system(size: 10, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? Color(hex: "2563EB") : Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shared Icon Helper

    private func settingIcon(_ name: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "1D3461"))
                .frame(width: 44, height: 44)
            Image(systemName: name)
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "3B82F6"))
        }
    }

    // MARK: - Actions

    private func saveAndContinue() {
        onboardingComplete = true
        showHome = true
    }
}

#Preview {
    AccessibilitySetupView()
}
