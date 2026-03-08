//
//  ContentView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete: Bool = false

    var body: some View {
        if onboardingComplete {
            HomeView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
}
