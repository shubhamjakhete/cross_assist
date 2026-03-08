//
//  HomeView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

struct HomeView: View {
    @State private var showDetection = false
    @State private var showSettings  = false
    @State private var showHistory   = false
    @State private var showCrossing  = false
    @State private var sensorPulse   = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "0A0F1E")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                scrollContent
                tabBar
            }

            // Floating voice button
            Button { print("voice command tapped") } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "2563EB"))
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(hex: "2563EB").opacity(0.4), radius: 12)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 100)
        }
        .fullScreenCover(isPresented: $showDetection) {
            MainDetectionView()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showHistory) {
            PlaceholderView(title: "History")
        }
        .fullScreenCover(isPresented: $showCrossing) {
            CrossingGuidanceView()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1D4ED8"))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("CrossAssist")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button { print("notifications tapped") } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1F2937"))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                greetingSection
                liveMapCard
                actionButtons
                recentActivityCard
                Spacer().frame(height: 120) // room for floating button
            }
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Good Morning, Alex")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "9CA3AF"))
            Text("Ready to cross\nsafely?")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(.white)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Live Map Card

    private var liveMapCard: some View {
        ZStack(alignment: .topLeading) {
            // Base card
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "111827"))

            // Faint grid texture
            GeometryReader { geo in
                let cols = 5
                let rows = 5
                let w = geo.size.width
                let h = geo.size.height

                Path { path in
                    // Vertical lines
                    for i in 1..<cols {
                        let x = w * CGFloat(i) / CGFloat(cols)
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: h))
                    }
                    // Horizontal lines
                    for i in 1..<rows {
                        let y = h * CGFloat(i) / CGFloat(rows)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Top row
                HStack(alignment: .top) {
                    // LIVE MAP pill
                    Text("LIVE MAP")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "60A5FA"))
                        .tracking(1.5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(hex: "1D4ED8").opacity(0.3))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "1D4ED8").opacity(0.6), lineWidth: 1)
                                )
                        )

                    Spacer()

                    // Location
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "9CA3AF"))
                        Text("San Francisco, CA")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "9CA3AF"))
                    }
                }

                Spacer()

                // Sensors active
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "22C55E"))
                            .frame(width: 8, height: 8)
                            .scaleEffect(sensorPulse ? 1.3 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                value: sensorPulse
                            )
                    }
                    Text("Sensors Active")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "E5E7EB"))
                }
            }
            .padding(16)
        }
        .frame(height: 160)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .onAppear { sensorPulse = true }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary — Start Crossing Assistant
            Button { showDetection = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "2563EB"))
                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                        Text("Start Crossing Assistant")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
            }

            // Secondary row
            HStack(spacing: 12) {
                Button { showDetection = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "1F2937"))
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                            Text("Practice Mode")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }

                Button { showSettings = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "1F2937"))
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                            Text("Settings")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Recent Activity Card

    private var recentActivityCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "1F2937"))
                    .frame(width: 44, height: 44)
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "6B7280"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recent Activity")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("3 successful crossings today")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "9CA3AF"))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "111827"))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "house.fill",               label: "HOME",    selected: true,  action: nil)
            tabItem(icon: "clock.arrow.2.circlepath", label: "HISTORY", selected: false, action: { showHistory  = true })
            tabItem(icon: "map",                      label: "MAP",     selected: false, action: { showCrossing = true })
            tabItem(icon: "person",                   label: "PROFILE", selected: false, action: { showSettings = true })
        }
        .padding(.vertical, 12)
        .background(Color(hex: "0F172A"))
    }

    private func tabItem(icon: String, label: String, selected: Bool, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Color(hex: "2563EB") : Color.white.opacity(0.4))
                Text(label)
                    .font(.system(size: 10, weight: selected ? .bold : .regular))
                    .foregroundStyle(selected ? Color(hex: "2563EB") : Color.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

#Preview {
    HomeView()
}
