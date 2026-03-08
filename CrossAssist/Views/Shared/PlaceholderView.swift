//
//  PlaceholderView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

struct PlaceholderView: View {
    let title: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: "0A0F1E").ignoresSafeArea()

            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("Coming soon")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                Button("Back") { dismiss() }
                    .foregroundStyle(Color(hex: "2563EB"))
            }
        }
    }
}

#Preview {
    PlaceholderView(title: "History")
}
