//
//  BottomActionBar.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

struct BottomActionBar: View {
    var onSettingsTapped:    () -> Void = {}
    var onMapTapped:         () -> Void = {}
    var onStopLongPress:     () -> Void = {}
    var onStopTapped:        () -> Void = {}
    var onTabHistoryTapped:  () -> Void = {}
    var onTabProfileTapped:  () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Action buttons row
            HStack(spacing: 16) {
                // Map
                Button { onMapTapped() } label: {
                    Image(systemName: "map.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.black.opacity(0.6),
                                    in: RoundedRectangle(cornerRadius: 16))
                }

                // STOP
                Button { onStopTapped() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text("STOP")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 56)
                    .background(Color(hex: "EF4444"),
                                in: RoundedRectangle(cornerRadius: 28))
                }
                .onLongPressGesture { onStopLongPress() }

                // Settings
                Button { onSettingsTapped() } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.black.opacity(0.6),
                                    in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Tab bar — 4 icons
            HStack(spacing: 0) {
                tabItem(icon: "camera.fill",                  selected: true,  action: nil)
                tabItem(icon: "map",                          selected: false, action: { onMapTapped() })
                tabItem(icon: "clock.arrow.counterclockwise", selected: false, action: { onTabHistoryTapped() })
                tabItem(icon: "person",                       selected: false, action: { onTabProfileTapped() })
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.75))
        }
    }

    private func tabItem(icon: String, selected: Bool, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(
                    selected ? Color(hex: "2563EB") : Color.white.opacity(0.5)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

#Preview {
        ZStack {
        Color.gray.ignoresSafeArea()
        VStack {
            Spacer()
            BottomActionBar(onSettingsTapped: { print("settings preview tapped") })
        }
    }
}
