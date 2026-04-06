//
//  VoiceAnnouncementService.swift
//  CrossAssist
//

import AVFoundation
import Foundation

@MainActor
final class VoiceAnnouncementService: NSObject {

    static let shared = VoiceAnnouncementService()

    private let synthesizer = AVSpeechSynthesizer()

    enum AnnouncementCategory: Equatable {
        case criticalObstacle
        case timerTooLate
        case timerWaitForNext
        case timerHurry
        case timerSafeToCross
        case dangerousObject
        case safeNoCountdown
        case crosswalkDetected
        case walkSignal
        case redLight
        case greenLight
        case pathClear
        case none
    }

    enum Urgency: Int {
        case low = 0
        case medium = 1
        case high = 2
    }

    private var lastCategory: AnnouncementCategory = .none
    private var lastCategoryTime: Date = .distantPast
    private var lastUrgency: Urgency = .low
    private var currentUrgency: Urgency = .low

    private func cooldown(for urgency: Urgency) -> TimeInterval {
        switch urgency {
        case .high:   return 8.0
        case .medium: return 10.0
        case .low:    return 15.0
        }
    }

    @discardableResult
    func announce(
        _ text: String,
        urgency: Urgency,
        category: AnnouncementCategory
    ) -> Bool {
        let voiceOn = (UserDefaults.standard.object(forKey: "voiceEnabled") as? Bool) ?? true
        guard voiceOn else { return false }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastCategoryTime)
        let requiredCooldown = cooldown(for: urgency)

        if category == lastCategory, elapsed < requiredCooldown {
            return false
        }

        if synthesizer.isSpeaking, urgency.rawValue < currentUrgency.rawValue {
            return false
        }

        if synthesizer.isSpeaking, urgency.rawValue > currentUrgency.rawValue {
            synthesizer.stopSpeaking(at: .word)
        }

        if synthesizer.isSpeaking, urgency.rawValue == currentUrgency.rawValue {
            return false
        }

        lastCategory = category
        lastCategoryTime = now
        lastUrgency = urgency
        currentUrgency = urgency

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.postUtteranceDelay = 0.5

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }

        synthesizer.speak(utterance)
        return true
    }

    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        currentUrgency = .low
        lastUrgency = .low
        lastCategory = .none
        lastCategoryTime = .distantPast
    }
}
