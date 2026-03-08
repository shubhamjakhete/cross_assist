//
//  ObjectTracker.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreGraphics

actor ObjectTracker {
    private static let emaAlpha: CGFloat = 0.4

    private var tracks: [Int: TrackedObject] = [:]
    private var nextId = 0

    func update(detections: [DetectedObject]) -> [TrackedObject] {
        guard !detections.isEmpty else {
            return Array(tracks.values)
        }

        let existingTrackIds = Set(tracks.keys)

        typealias Match = (trackId: Int, detIdx: Int, overlap: CGFloat)
        var candidates: [Match] = []
        for (trackId, track) in tracks {
            for (idx, det) in detections.enumerated() {
                let overlap = iou(track.boundingBox, det.boundingBox)
                if overlap > 0 {
                    candidates.append((trackId, idx, overlap))
                }
            }
        }
        candidates.sort { $0.overlap > $1.overlap }

        var matchedDetections = Set<Int>()
        var matchedTracks = Set<Int>()
        for match in candidates where !matchedDetections.contains(match.detIdx) && !matchedTracks.contains(match.trackId) {
            matchedDetections.insert(match.detIdx)
            matchedTracks.insert(match.trackId)
            let track = tracks[match.trackId]!
            let det = detections[match.detIdx]
            let smoothed = smoothBox(track.boundingBox, det.boundingBox)
            tracks[match.trackId] = TrackedObject(
                id: match.trackId,
                label: det.label,
                confidence: det.confidence,
                boundingBox: smoothed
            )
        }

        for (idx, det) in detections.enumerated() where !matchedDetections.contains(idx) {
            let id = nextId
            nextId += 1
            tracks[id] = TrackedObject(
                id: id,
                label: det.label,
                confidence: det.confidence,
                boundingBox: det.boundingBox
            )
        }

        for trackId in existingTrackIds where !matchedTracks.contains(trackId) {
            tracks.removeValue(forKey: trackId)
        }

        return Array(tracks.values)
    }

    private func smoothBox(_ previous: CGRect, _ current: CGRect) -> CGRect {
        let x = previous.origin.x * (1 - Self.emaAlpha) + current.origin.x * Self.emaAlpha
        let y = previous.origin.y * (1 - Self.emaAlpha) + current.origin.y * Self.emaAlpha
        let w = previous.width * (1 - Self.emaAlpha) + current.width * Self.emaAlpha
        let h = previous.height * (1 - Self.emaAlpha) + current.height * Self.emaAlpha
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let unionArea = a.area + b.area - intersection.area
        guard unionArea > 0 else { return 0 }
        return intersection.area / unionArea
    }
}

private extension CGRect {
    nonisolated var area: CGFloat {
        width * height
    }
}

