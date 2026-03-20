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

    /// Live timer recommendation from the parent detection view.
    /// nil when opened manually (shows default SAFE state).
    var timerRecommendation: WalkSignalRecommendation? = nil
    /// Distance to the nearest pedestrian signal in metres, if available.
    var signalDistance: Float? = nil

    @State private var crossingStatus: CrossingStatus  = .safe
    @State private var crossingProgress: Double        = 0.35
    @State private var pulse                           = false
    @State private var showHistory                     = false
    @State private var showSettings                    = false

    /// Tracks the initial countdown so progress can be computed as a ratio.
    @State private var initialSeconds: Int = 0
    /// 0.0 (done) → 1.0 (full) drives the progress bar.
    @State private var timerProgress: Double = 1.0

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
        .onAppear {
            pulse = false
            withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: timerRecommendation) { _, rec in
            // Capture initial seconds on first non-nil detection
            if let s = rec?.detectedSeconds, initialSeconds == 0 {
                initialSeconds = s
            }
            // Update progress bar
            if let s = rec?.detectedSeconds, initialSeconds > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    timerProgress = Double(s) / Double(initialSeconds)
                }
            } else if rec == .waitForNext {
                withAnimation(.easeInOut(duration: 0.3)) { timerProgress = 0.0 }
            } else if rec == .safeNoCountdown {
                withAnimation(.easeInOut(duration: 0.3)) { timerProgress = 1.0 }
            }
            // Restart pulse at the new urgency-based speed
            pulse = false
            withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
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
                .animation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true), value: pulse)

            // Middle ring
            Circle()
                .fill(middleRingColor.opacity(0.6))
                .frame(width: 124, height: 124)
                .scaleEffect(pulse ? 1.05 : 1.0)
                .animation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true), value: pulse)

            // Inner circle
            Circle()
                .fill(innerCircleColor)
                .frame(width: 88, height: 88)
                .scaleEffect(pulse ? 1.05 : 1.0)
                .animation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true), value: pulse)

            // Show live countdown number when seconds are available;
            // fall back to the walking figure icon otherwise.
            if let seconds = timerRecommendation?.detectedSeconds {
                VStack(spacing: 2) {
                    Text("\(seconds)")
                        .font(.system(size: 52, weight: .heavy))
                        .foregroundColor(.white)
                    Text("sec")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                Image(systemName: "figure.walk")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
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
                    Text(formattedSignalDistance)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(progressBarColor)
                    Text("left")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                }
            }

            ProgressView(value: timerProgress, total: 1.0)
                .tint(progressBarColor)
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
        if let rec = timerRecommendation {
            switch rec {
            case .safeToCross, .safeNoCountdown: return Color(hex: "16A34A")
            case .hurry:                         return Color(hex: "F97316")
            case .tooLate, .waitForNext:         return Color(hex: "EF4444")
            default: break
            }
        }
        switch crossingStatus {
        case .safe:     return Color(hex: "16A34A")
        case .wait:     return Color(hex: "DC2626")
        case .checking: return Color(hex: "CA8A04")
        }
    }

    private var middleRingColor: Color {
        if let rec = timerRecommendation {
            switch rec {
            case .safeToCross, .safeNoCountdown: return Color(hex: "14532D")
            case .hurry:                         return Color(hex: "431407")
            case .tooLate, .waitForNext:         return Color(hex: "450A0A")
            default: break
            }
        }
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
        if let rec = timerRecommendation {
            switch rec {
            case .safeToCross:    return "Safe to cross"
            case .hurry:          return "Hurry now"
            case .tooLate,
                 .waitForNext:    return "Please wait"
            case .safeNoCountdown: return "Safe to cross now"
            default: break
            }
        }
        switch crossingStatus {
        case .safe:     return "Safe to cross now"
        case .wait:     return "Please wait"
        case .checking: return "Checking..."
        }
    }

    private var statusTitleColor: Color {
        if let rec = timerRecommendation {
            switch rec {
            case .safeToCross, .safeNoCountdown: return .white
            case .hurry:                         return Color(hex: "F97316")
            case .tooLate, .waitForNext:         return Color(hex: "EF4444")
            default: break
            }
        }
        switch crossingStatus {
        case .safe:     return .white
        case .wait:     return Color(hex: "EF4444")
        case .checking: return Color(hex: "EAB308")
        }
    }

    private var statusSubtitle: String {
        if let rec = timerRecommendation {
            switch rec {
            case .safeToCross(let s):   return "\(s) seconds remaining"
            case .hurry(let s):         return "Only \(s)s left — cross quickly"
            case .tooLate(let s):       return "\(s)s left — too late to cross safely"
            case .waitForNext:          return "Wait for the next signal"
            case .safeNoCountdown:      return "Clear path detected"
            default: break
            }
        }
        switch crossingStatus {
        case .safe:     return "Clear path detected in front of you"
        case .wait:     return "Vehicles detected — do not cross"
        case .checking: return "Scanning for obstacles..."
        }
    }

    /// Pulse animation duration scales with urgency — fastest for critical states.
    private var pulseDuration: Double {
        guard let rec = timerRecommendation else { return 1.5 }
        switch rec {
        case .safeToCross, .safeNoCountdown: return 1.5
        case .hurry:                         return 0.8
        case .tooLate, .waitForNext:         return 0.4
        default:                             return 1.5
        }
    }

    /// Progress bar colour: blue → orange → red as time runs out.
    private var progressBarColor: Color {
        if timerProgress > 0.5  { return Color(hex: "2563EB") }
        if timerProgress > 0.25 { return Color(hex: "F97316") }
        return Color(hex: "EF4444")
    }

    /// Formatted signal distance string from live camera data.
    private var formattedSignalDistance: String {
        guard let dist = signalDistance else { return "--" }
        return dist < 10
            ? String(format: "%.1fm", dist)
            : String(format: "%.0fm", dist)
    }
}

#Preview {
    CrossingGuidanceView()
}
