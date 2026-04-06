//
//  WalkSignalCountdownManager.swift
//  CrossAssist
//

import Combine
import Foundation

@MainActor
final class WalkSignalCountdownManager: ObservableObject {

    static let shared = WalkSignalCountdownManager()

    @Published var currentSeconds: Int?
    @Published var recommendation: WalkSignalRecommendation = .unknown

    private var timer: Timer?
    private var lastOCRTime: Date = .distantPast
    private var signalLastSeenTime: Date = .distantPast
    private let signalTimeoutSeconds: TimeInterval = 3.0

    private init() {}

    /// Called when OCR reads a countdown digit from the walk signal region.
    func updateFromOCR(_ rawSeconds: Int) {
        signalLastSeenTime = Date()
        lastOCRTime = Date()

        if let current = currentSeconds {
            let diff = abs(current - rawSeconds)
            if diff <= 2 {
                return
            }
        }

        currentSeconds = rawSeconds
        restartTimer()
    }

    /// Solid WALK / no digits visible — keep last seen time fresh; may set safeNoCountdown.
    func signalDetectedNoCountdown() {
        signalLastSeenTime = Date()
        if currentSeconds == nil {
            recommendation = .safeNoCountdown
        }
    }

    /// Call each frame while no pedestrian-signal object is in view.
    func signalNotDetected() {
        let elapsed = Date().timeIntervalSince(signalLastSeenTime)
        if elapsed > signalTimeoutSeconds {
            reset()
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        updateRecommendation()
        guard let seconds = currentSeconds, seconds > 0 else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let current = currentSeconds else { return }
        let next = current - 1
        currentSeconds = next > 0 ? next : 0
        updateRecommendation()

        if next <= 0 {
            timer?.invalidate()
            timer = nil
        }
    }

    private func updateRecommendation() {
        guard let s = currentSeconds else {
            recommendation = .unknown
            return
        }
        switch s {
        case 11...99:
            recommendation = .safeToCross(seconds: s)
        case 4...10:
            recommendation = .hurry(seconds: s)
        case 1...3:
            recommendation = .tooLate(seconds: s)
        case 0:
            recommendation = .waitForNext
        default:
            recommendation = .unknown
        }
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        currentSeconds = nil
        recommendation = .unknown
        lastOCRTime = .distantPast
        signalLastSeenTime = .distantPast
    }
}
