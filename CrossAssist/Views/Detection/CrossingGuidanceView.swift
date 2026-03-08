//
//  CrossingGuidanceView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import MapKit
import SwiftUI

// MARK: - Crossing Status

enum CrossingStatus { case safe, wait, checking }

// MARK: - CrossingGuidanceView

struct CrossingGuidanceView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var crossingStatus: CrossingStatus  = .safe
    @State private var crossingProgress: Double        = 0.35
    @State private var pulse                           = false
    @State private var showHistory                     = false
    @State private var showSettings                    = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0A0F1E").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroCircle
                        statusText
                        directionIndicators
                        crossingProgressSection
                        mapCard
                        Spacer().frame(height: 24)
                    }
                }

                tabBar
            }
        }
        .onAppear { pulse = true }
        .fullScreenCover(isPresented: $showHistory) {
            PlaceholderView(title: "History")
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
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

            Text("CrossAssist")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button { print("more options") } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Hero Circle

    private var heroCircle: some View {
        ZStack {
            // Outermost ring
            Circle()
                .fill(outerRingColor)
                .frame(width: 160, height: 160)
                .scaleEffect(pulse ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

            // Middle ring
            Circle()
                .fill(middleRingColor.opacity(0.6))
                .frame(width: 124, height: 124)
                .scaleEffect(pulse ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

            // Inner circle
            Circle()
                .fill(innerCircleColor)
                .frame(width: 88, height: 88)
                .scaleEffect(pulse ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

            Image(systemName: "figure.walk")
                .font(.system(size: 36))
                .foregroundStyle(.white)
        }
        .padding(.top, 16)
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(statusTitleColor)
                .multilineTextAlignment(.center)

            Text(statusSubtitle)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "9CA3AF"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 12)
    }

    // MARK: - Direction Indicators

    private var directionIndicators: some View {
        HStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: "6B7280"))
                Text("LEFT")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: "6B7280"))
            }

            Spacer()

            VStack(spacing: 6) {
                Image(systemName: "chevron.up.2")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(hex: "16A34A"))
                Text("FORWARD")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: "16A34A"))
            }

            Spacer()

            VStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: "6B7280"))
                Text("RIGHT")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: "6B7280"))
            }

            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
    }

    // MARK: - Crossing Progress

    private var crossingProgressSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Crossing progress")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "E5E7EB"))

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("12m")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "2563EB"))
                    Text("left")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                }
            }

            ProgressView(value: crossingProgress, total: 1.0)
                .tint(Color(hex: "2563EB"))
                .scaleEffect(x: 1, y: 2.5, anchor: .center)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1F2937"))
                        .frame(height: 8)
                )
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Map Card

    private var mapCard: some View {
        Map(position: .constant(.region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span:   MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))))
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(true)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            Spacer()

            // Tab 1 — Guidance (selected)
            VStack(spacing: 4) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "2563EB"))
                Text("GUIDANCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color(hex: "2563EB"))
            }

            Spacer()

            // Tab 2 — History
            Button { showHistory = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Text("HISTORY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Tab 3 — Settings
            Button { showSettings = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Text("SETTINGS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(hex: "0A0F1E"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    // MARK: - Computed Style Helpers

    private var innerCircleColor: Color {
        switch crossingStatus {
        case .safe:     return Color(hex: "16A34A")
        case .wait:     return Color(hex: "DC2626")
        case .checking: return Color(hex: "CA8A04")
        }
    }

    private var middleRingColor: Color {
        switch crossingStatus {
        case .safe:     return Color(hex: "14532D")
        case .wait:     return Color(hex: "450A0A")
        case .checking: return Color(hex: "422006")
        }
    }

    private var outerRingColor: Color {
        Color(hex: "0D2B1F")
    }

    private var statusTitle: String {
        switch crossingStatus {
        case .safe:     return "Safe to cross now"
        case .wait:     return "Please wait"
        case .checking: return "Checking..."
        }
    }

    private var statusTitleColor: Color {
        switch crossingStatus {
        case .safe:     return .white
        case .wait:     return Color(hex: "EF4444")
        case .checking: return Color(hex: "EAB308")
        }
    }

    private var statusSubtitle: String {
        switch crossingStatus {
        case .safe:     return "Clear path detected in front of you"
        case .wait:     return "Vehicles detected — do not cross"
        case .checking: return "Scanning for obstacles..."
        }
    }
}

#Preview {
    CrossingGuidanceView()
}
