//
//  OnboardingView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var showDetection = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar
                heroCard
                titleSection
                buttons
                trustBadges
            }
        }
        .background(Color(hex: "0A0F1E").ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(isPresented: $showDetection) {
            MainDetectionView()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // X button — dev reset
            Button {
                onboardingComplete = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1), in: Circle())
            }

            Spacer()

            // Logo + name
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "2563EB"))
                        .frame(width: 32, height: 32)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                Text("CrossAssist")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Balancing spacer
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 0) {
            // Mock iPhone
            ZStack {
                // Outer phone shell stroke
                RoundedRectangle(cornerRadius: 36)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 36)
                            .fill(Color(hex: "1A2744"))
                    )
                    .frame(width: 180, height: 300)

                // Phone screen content
                ZStack {
                    // Screen background
                    Color(hex: "0D1F35")

                    // Zebra crossing stripes
                    VStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 160, height: 16)
                        }
                    }
                    .offset(y: 60)

                    // Walking person
                    Image(systemName: "figure.walk")
                        .font(.system(size: 52))
                        .foregroundStyle(Color(hex: "F59E0B"))
                        .offset(x: -10, y: -30)

                    // Status pill
                    Capsule()
                        .fill(Color(hex: "1F2937").opacity(0.9))
                        .frame(height: 26)
                        .overlay(
                            Text("Pedestrian detected")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "9CA3AF"))
                        )
                        .padding(.horizontal, 12)
                        .offset(y: 110)

                    // Small circular button at bottom
                    ZStack {
                        Circle()
                            .fill(Color(hex: "1F3A5F"))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                    .offset(y: 125)
                }
                .frame(width: 178, height: 298)
                .clipShape(RoundedRectangle(cornerRadius: 34))

                // Notch
                Capsule()
                    .fill(Color.black)
                    .frame(width: 60, height: 16)
                    .offset(y: -140)
            }
            .frame(width: 180, height: 300)

            // AI Detection Active badge
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "2563EB"))
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("AI DETECTION ACTIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "2563EB"))
                    .tracking(1.5)
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "111827"))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 10) {
            Text("CrossAssist")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.white)

            Text("Smart camera guidance for safer\npedestrian crossings.")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "9CA3AF"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.top, 28)
        .padding(.horizontal, 24)
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: 14) {
            // Start Setup
            Button {
                onboardingComplete = true
                showDetection = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "2563EB"))
                    HStack(spacing: 10) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                        Text("Start Setup")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            }

            // Continue as Guest
            Button {
                onboardingComplete = true
                showDetection = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "1F2937"))
                    Text("Continue as Guest")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    // MARK: - Trust Badges

    private var trustBadges: some View {
        HStack(spacing: 0) {
            Spacer()
            badge(icon: "lock.shield.fill", label: "SECURE")
            Spacer()
            badge(icon: "figure.stand",     label: "INCLUSIVE")
            Spacer()
            badge(icon: "cpu",              label: "AI DRIVEN")
            Spacer()
        }
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    private func badge(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "6B7280"))
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "6B7280"))
                .tracking(1.5)
        }
    }
}

#Preview {
    OnboardingView()
}
