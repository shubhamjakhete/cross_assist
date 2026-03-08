//
//  EmergencyView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import MapKit
import SwiftUI

struct EmergencyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pulse        = false
    @State private var sirenActive  = false
    @State private var showSettings = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0A0F1E").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                        actionButtons
                        locationCard
                        Spacer().frame(height: 24)
                    }
                }

                tabBar
            }
        }
        .onAppear { pulse = true }
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

            Text("CrossAssist Emergency")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 12) {
            // Warning icon with pulse
            ZStack {
                Circle()
                    .fill(Color(hex: "4B0000"))
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(Color(hex: "7F1D1D"))
                    .frame(width: 64, height: 64)
                Image(systemName: "exclamationmark.diamond.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: "EF4444"))
            }
            .scaleEffect(pulse ? 1.08 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)

            Text("Need Help?")
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(.white)

            Text("Immediate support is one tap away.")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "9CA3AF"))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 20)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            // Button 1 — Call Emergency Contact
            Button {
                if let url = URL(string: "tel://911") {
                    UIApplication.shared.open(url)
                }
                print("calling emergency contact")
            } label: {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "phone.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Call Emergency Contact")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Contacts: Mom, Dad, John")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }

                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "DC2626")))
            }
            .buttonStyle(.plain)

            // Button 2 — Share Location
            Button {
                print("share location tapped — will wire to Firebase later")
            } label: {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share Location")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Live tracking for 30 mins")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }

                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "2563EB")))
            }
            .buttonStyle(.plain)

            // Button 3 — Activate Loud Alert
            Button {
                sirenActive.toggle()
                if sirenActive {
                    print("siren activated — will wire to AVAudioEngine later")
                }
            } label: {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activate Loud Alert")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Plays high-pitched siren")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "9CA3AF"))
                    }

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(sirenActive ? Color(hex: "EF4444") : Color(hex: "374151"))
                        Text(sirenActive ? "ON" : "OFF")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 28)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "1F2937")))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
    }

    // MARK: - Current Location Card

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Location")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Capsule()
                    .fill(Color(hex: "1D3461"))
                    .overlay(
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: "22C55E"))
                                .frame(width: 6, height: 6)
                            Text("GPS ACTIVE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color(hex: "3B82F6"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    )
                    .fixedSize()
            }

            // Map with address overlay
            ZStack(alignment: .bottom) {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    span:   MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))))
                .disabled(true)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "EF4444"))
                    Text("794 McAllister St, San Francisco, CA")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "E5E7EB"))
                }
                .padding(10)
                .background(Color.black.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            Spacer()

            // Tab 1 — Home
            Button { dismiss() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Text("HOME")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Tab 2 — Alerts (selected)
            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "EF4444"))
                Text("ALERTS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color(hex: "EF4444"))
            }

            Spacer()

            // Tab 3 — Contacts
            Button { print("contacts tapped") } label: {
                VStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Text("CONTACTS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Tab 4 — Settings
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
}

#Preview {
    EmergencyView()
}
