//
//  CrossAssistApp.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

@main
struct CrossAssistApp: App {

    init() {
        if CommandLine.arguments.contains("--resetOnboarding") {
            UserDefaults.standard.set(false, forKey: "onboardingComplete")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
