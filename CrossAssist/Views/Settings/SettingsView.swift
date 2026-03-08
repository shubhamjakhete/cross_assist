//
//  SettingsView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI
import UIKit

// MARK: - Settings Control Enum

enum SettingsControl {
    case toggle(Binding<Bool>)
    case chevron
    case none
}

// MARK: - SettingsRow

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let control: SettingsControl
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "9CA3AF"))
                    }
                }

                Spacer()

                switch control {
                case .toggle(let binding):
                    Toggle("", isOn: binding)
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "2563EB")))
                        .labelsHidden()
                case .chevron:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "6B7280"))
                case .none:
                    EmptyView()
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .disabled(action == nil && controlIsChevron)
    }

    private var controlIsChevron: Bool {
        if case .chevron = control { return false }  // still allow sheet triggers via action
        return false
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("voiceEnabled")          private var voiceEnabled       = true
    @AppStorage("hapticsEnabled")        private var hapticsEnabled     = true
    @AppStorage("highContrastMode")      private var highContrast       = false
    @AppStorage("autoAlert")             private var autoAlert          = false
    @AppStorage("detectionSensitivity")  private var sensitivity        = "Normal"
    @AppStorage("onboardingComplete")    private var onboardingComplete = true

    @State private var showSensitivitySheet = false
    @State private var showEmergency        = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0A0F1E").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        profileCard
                        assistanceSection
                        displaySection
                        safetySection
                        aboutSection
                        signOutButton
                        Spacer().frame(height: 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showSensitivitySheet) {
            sensitivitySheet
        }
        .fullScreenCover(isPresented: $showEmergency) {
            EmergencyView()
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

            Text("Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "1D4ED8"))
                    .frame(width: 56, height: 56)
                Text("A")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Alex")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("Guest User")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "9CA3AF"))
            }

            Spacer()

            Button { print("edit profile") } label: {
                Text("Edit")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "3B82F6"))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: "111827")))
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Assistance Section

    private var assistanceSection: some View {
        VStack(spacing: 0) {
            sectionHeader("ASSISTANCE")

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "person.wave.2.fill",
                    iconColor: Color(hex: "3B82F6"),
                    title: "Voice Guidance",
                    subtitle: "Audio navigation cues",
                    control: .toggle($voiceEnabled)
                )
                divider
                SettingsRow(
                    icon: "iphone.radiowaves.left.and.right",
                    iconColor: Color(hex: "3B82F6"),
                    title: "Haptic Feedback",
                    subtitle: "Vibration alerts",
                    control: .toggle($hapticsEnabled)
                )
                divider
                SettingsRow(
                    icon: "dot.radiowaves.forward",
                    iconColor: Color(hex: "3B82F6"),
                    title: "Detection Sensitivity",
                    subtitle: sensitivity,
                    control: .chevron,
                    action: { showSensitivitySheet = true }
                )
                divider
                SettingsRow(
                    icon: "waveform",
                    iconColor: Color(hex: "3B82F6"),
                    title: "Speech Rate",
                    subtitle: "Normal",
                    control: .chevron,
                    action: { print("speech rate tapped") }
                )
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(spacing: 0) {
            sectionHeader("DISPLAY")

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "circle.lefthalf.filled",
                    iconColor: Color(hex: "8B5CF6"),
                    title: "High Contrast Mode",
                    subtitle: "Increase visibility",
                    control: .toggle($highContrast)
                )
                divider
                SettingsRow(
                    icon: "textformat.size",
                    iconColor: Color(hex: "8B5CF6"),
                    title: "Text Size",
                    subtitle: "Medium",
                    control: .chevron,
                    action: { print("text size tapped") }
                )
                divider
                SettingsRow(
                    icon: "moon.fill",
                    iconColor: Color(hex: "8B5CF6"),
                    title: "Dark Mode",
                    subtitle: "Always On",
                    control: .chevron,
                    action: { print("dark mode tapped") }
                )
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Safety Section

    private var safetySection: some View {
        VStack(spacing: 0) {
            sectionHeader("SAFETY")

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "person.crop.circle.badge.exclamationmark",
                    iconColor: Color(hex: "EF4444"),
                    title: "Emergency Contact",
                    subtitle: "Not configured",
                    control: .chevron,
                    action: { showEmergency = true }
                )
                divider
                SettingsRow(
                    icon: "bell.badge.fill",
                    iconColor: Color(hex: "EF4444"),
                    title: "Auto-Alert",
                    subtitle: "Send location if stopped 30s",
                    control: .toggle($autoAlert)
                )
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 0) {
            sectionHeader("ABOUT")

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "info.circle.fill",
                    iconColor: Color(hex: "6B7280"),
                    title: "App Version",
                    subtitle: "1.0.0 (Build 1)",
                    control: .none
                )
                divider
                SettingsRow(
                    icon: "lock.shield.fill",
                    iconColor: Color(hex: "6B7280"),
                    title: "Privacy Policy",
                    subtitle: "",
                    control: .chevron,
                    action: {
                        if let url = URL(string: "https://crossassist.app/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }
                )
                divider
                SettingsRow(
                    icon: "envelope.fill",
                    iconColor: Color(hex: "6B7280"),
                    title: "Send Feedback",
                    subtitle: "",
                    control: .chevron,
                    action: {
                        if let url = URL(string: "mailto:feedback@crossassist.app") {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            onboardingComplete = false
            dismiss()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "EF4444"), lineWidth: 1.5)
                    )
                Text("Sign Out")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "EF4444"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Sensitivity Sheet

    private var sensitivitySheet: some View {
        VStack(spacing: 0) {
            Text("Detection Sensitivity")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(20)

            ForEach(["Low", "Normal", "High"], id: \.self) { level in
                Button {
                    sensitivity = level
                    showSensitivitySheet = false
                } label: {
                    VStack(spacing: 0) {
                        HStack {
                            Text(level)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                            Spacer()
                            if sensitivity == level {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(hex: "2563EB"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                    }
                }
            }
        }
        .background(Color(hex: "111827"))
        .presentationDetents([.height(220)])
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color(hex: "6B7280"))
            .tracking(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 68)
    }
}

#Preview {
    SettingsView()
}
