//
//  ObjectTracker.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreGraphics
import CoreVideo

actor ObjectTracker {
    private static let emaAlpha: CGFloat = 0.25

    private var tracks: [Int: TrackedObject] = [:]
    private var nextId = 0
    private var depthService: DepthEstimationService?
    /// Global counter for throttling Vision OCR on pedestrian signals (~every 10th frame).
    private var ocrFrameCounter: Int = 0

    func setDepthService(_ service: DepthEstimationService) {
        depthService = service
    }

    /// Update tracks with a new set of YOLO detections.
    ///
    /// - Parameters:
    ///   - detections: Raw detections from `DetectionService`.
    ///   - frame:      The source `CameraFrame` (`@unchecked Sendable`) used to
    ///                 classify traffic-light colours.  Pass `nil` to skip colour
    ///                 classification (depth-enrichment frames, for example).
    func update(detections: [DetectedObject], frame: CameraFrame?) async -> [TrackedObject] {
        ocrFrameCounter += 1
        let runOCR = (ocrFrameCounter % 10 == 0)

        guard !detections.isEmpty else {
            await MainActor.run { WalkSignalCountdownManager.shared.signalNotDetected() }
            return Array(tracks.values)
        }

        let existingTrackIds = Set(tracks.keys)

        typealias Match = (trackId: Int, detIdx: Int, overlap: CGFloat)
        var candidates: [Match] = []
        for (trackId, track) in tracks {
            for (idx, det) in detections.enumerated() {
                let overlap = iou(track.boundingBox, det.boundingBox)
                if overlap >= 0.25 {
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
            let det   = detections[match.detIdx]
            let smoothed = smoothBox(track.boundingBox, det.boundingBox)
            var updated = TrackedObject(
                id: match.trackId,
                label: det.label,
                confidence: det.confidence,
                boundingBox: smoothed,
                distanceMeters: DistanceEstimator.estimateDistance(
                    label: det.label,
                    boundingBox: smoothed
                ),
                frameCount: track.frameCount + 1,
                source: det.source
            )
            updated.trafficLightState = classifyIfTrafficLight(
                label: det.label, box: smoothed, frame: frame,
                previous: track.trafficLightState
            )
            tracks[match.trackId] = updated
        }

        for (idx, det) in detections.enumerated() where !matchedDetections.contains(idx) {
            let id = nextId
            nextId += 1
            var newTrack = TrackedObject(
                id: id,
                label: det.label,
                confidence: det.confidence,
                boundingBox: det.boundingBox,
                distanceMeters: DistanceEstimator.estimateDistance(
                    label: det.label,
                    boundingBox: det.boundingBox
                ),
                source: det.source
            )
            newTrack.trafficLightState = classifyIfTrafficLight(
                label: det.label, box: det.boundingBox, frame: frame, previous: nil
            )
            tracks[id] = newTrack
        }

        await syncWalkSignalManager(detections: detections, frame: frame, runOCR: runOCR)

        let managerRec = await MainActor.run { WalkSignalCountdownManager.shared.recommendation }
        for id in tracks.keys {
            guard var t = tracks[id], isPedestrianSignalLabel(t.label) else { continue }
            t.walkSignalRecommendation = managerRec
            tracks[id] = t
        }

        for trackId in existingTrackIds where !matchedTracks.contains(trackId) {
            tracks.removeValue(forKey: trackId)
        }

        // Apply label-specific minimum track age before returning.
        // The internal `tracks` dict is intentionally left unfiltered so that
        // young tracks still participate in IoU matching on the next frame.
        // Person tracks need extra stability to filter out static walk-sign
        // figures (which also accumulate age quickly but are caught earlier by
        // the aspect-ratio filter in DetectionService).
        let visible = tracks.values.filter { track in
            let minAge = track.label == "person" ? 8 : 1
            return track.frameCount >= minAge
        }

        // MARK: - Crosswalk deduplication
        // crosswalkDetection fires on each stripe of a crosswalk separately,
        // producing 4-8 overlapping boxes on the same surface.  Merge them all
        // into a single unified bounding box (union hull of all individual boxes)
        // keyed on the highest-confidence detection.
        let crosswalks = visible.filter { $0.label == "CROSSWALK" }
        let others     = visible.filter { $0.label != "CROSSWALK" }

        let mergedVisible: [TrackedObject]
        if crosswalks.count > 1 {
            let minX = crosswalks.map { $0.boundingBox.minX }.min()!
            let minY = crosswalks.map { $0.boundingBox.minY }.min()!
            let maxX = crosswalks.map { $0.boundingBox.maxX }.max()!
            let maxY = crosswalks.map { $0.boundingBox.maxY }.max()!
            let mergedBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

            let best = crosswalks.max(by: { $0.confidence < $1.confidence })!
            var merged = TrackedObject(
                id: best.id,
                label: "CROSSWALK",
                confidence: best.confidence,
                boundingBox: mergedBox,
                distanceMeters: best.distanceMeters,
                frameCount: best.frameCount,
                source: best.source
            )
            merged.walkSignalRecommendation = best.walkSignalRecommendation
            mergedVisible = others + [merged]
        } else {
            mergedVisible = others + crosswalks
        }

        let relabeledVisible = relabelPedestrianRedWithoutCrosswalkRedOverlap(mergedVisible)

        // MARK: - Pedestrian signal deduplication
        // Same physical signal may produce multiple overlapping boxes; merge per label.
        let signalLabels = ["RED LIGHT", "GREEN LIGHT", "WALK SIGNAL", "SIGNAL"]
        var signalDeduped: [TrackedObject] = []
        let nonSignalObjects = relabeledVisible.filter { !signalLabels.contains($0.label) }

        for sigLabel in signalLabels {
            let group = relabeledVisible.filter { $0.label == sigLabel }
            guard !group.isEmpty else { continue }
            if group.count == 1 {
                signalDeduped.append(group[0])
                continue
            }
            let minXs = group.map { $0.boundingBox.minX }.min()!
            let minYs = group.map { $0.boundingBox.minY }.min()!
            let maxXs = group.map { $0.boundingBox.maxX }.max()!
            let maxYs = group.map { $0.boundingBox.maxY }.max()!
            let mergedSigBox = CGRect(x: minXs, y: minYs, width: maxXs - minXs, height: maxYs - minYs)

            let bestSig = group.max(by: { $0.confidence < $1.confidence })!
            var mergedSig = TrackedObject(
                id: bestSig.id,
                label: sigLabel,
                confidence: bestSig.confidence,
                boundingBox: mergedSigBox,
                distanceMeters: bestSig.distanceMeters,
                frameCount: bestSig.frameCount,
                source: bestSig.source
            )
            mergedSig.trafficLightState = bestSig.trafficLightState
            mergedSig.walkSignalRecommendation = group
                .compactMap { $0.walkSignalRecommendation }
                .max(by: { $0.urgency < $1.urgency })
            signalDeduped.append(mergedSig)
        }

        return nonSignalObjects + signalDeduped
    }

    /// Pedestrian-only `RED LIGHT` with no overlapping crosswalk-model vehicle red
    /// is ambiguous (blinking hand); downgrade to `SIGNAL` for neutral UI.
    private func relabelPedestrianRedWithoutCrosswalkRedOverlap(_ objects: [TrackedObject]) -> [TrackedObject] {
        let crosswalkRedBoxes = objects
            .filter { $0.label == "RED LIGHT" && $0.source == "crosswalk" }
            .map(\.boundingBox)

        return objects.map { obj in
            guard obj.label == "RED LIGHT", obj.source == "pedestrian" else { return obj }
            let overlapsVehicleRed = crosswalkRedBoxes.contains { iou($0, obj.boundingBox) > 0.25 }
            if overlapsVehicleRed { return obj }
            return pedestrianRedRelabeledAsSignal(obj)
        }
    }

    private func pedestrianRedRelabeledAsSignal(_ obj: TrackedObject) -> TrackedObject {
        var relabeled = TrackedObject(
            id: obj.id,
            label: "SIGNAL",
            confidence: obj.confidence,
            boundingBox: obj.boundingBox,
            distanceMeters: obj.distanceMeters,
            frameCount: obj.frameCount,
            source: obj.source
        )
        relabeled.trafficLightState = obj.trafficLightState
        relabeled.walkSignalRecommendation = obj.walkSignalRecommendation
        return relabeled
    }

    // MARK: - Traffic light classification

    /// Runs `TrafficLightColorClassifier` when the label is a traffic light and
    /// a pixel buffer is available; returns the previous state otherwise so the
    /// card doesn't flash to `.unknown` on frames where classification is skipped.
    private func classifyIfTrafficLight(
        label: String,
        box: CGRect,
        frame: CameraFrame?,
        previous: TrafficLightState?
    ) -> TrafficLightState? {
        guard label.lowercased().contains("traffic light") else { return nil }
        guard let pb = frame?.pixelBuffer else { return previous }

        let bufW = CVPixelBufferGetWidth(pb)
        let bufH = CVPixelBufferGetHeight(pb)
        let state = TrafficLightColorClassifier.classify(
            pixelBuffer: pb,
            boundingBox: box,
            frameSize: CGSize(width: bufW, height: bufH)
        )
        // Keep previous state if the classifier returns `.unknown` to avoid
        // flickering on frames where the bulb is momentarily hard to read.
        if state.color == .unknown, let prev = previous { return prev }
        return state
    }

    // MARK: - Pedestrian signal detection

    private func syncWalkSignalManager(
        detections: [DetectedObject],
        frame: CameraFrame?,
        runOCR: Bool
    ) async {
        let pedDets = detections.filter { isPedestrianSignalLabel($0.label) }
        guard !pedDets.isEmpty else {
            await MainActor.run { WalkSignalCountdownManager.shared.signalNotDetected() }
            return
        }
        guard let best = pedDets.max(by: { $0.confidence < $1.confidence }) else { return }

        if runOCR, let pb = frame?.pixelBuffer {
            let fw = CVPixelBufferGetWidth(pb)
            let fh = CVPixelBufferGetHeight(pb)
            let rawRec = WalkSignalTimerService.detectCountdown(
                pixelBuffer: pb,
                boundingBox: best.boundingBox,
                frameSize: CGSize(width: fw, height: fh)
            )
            await MainActor.run {
                switch rawRec {
                case .safeToCross(let s), .hurry(let s), .tooLate(let s):
                    WalkSignalCountdownManager.shared.updateFromOCR(s)
                case .safeNoCountdown:
                    WalkSignalCountdownManager.shared.signalDetectedNoCountdown()
                case .waitForNext:
                    WalkSignalCountdownManager.shared.updateFromOCR(0)
                case .unknown:
                    WalkSignalCountdownManager.shared.signalDetectedNoCountdown()
                }
            }
        } else {
            await MainActor.run {
                WalkSignalCountdownManager.shared.signalDetectedNoCountdown()
            }
        }
    }

    private func isPedestrianSignalLabel(_ label: String) -> Bool {
        let lower = label.lowercased()
        return ["walk signal", "green light", "red light", "signal"].contains(lower)
    }

    // MARK: - EMA smoothing

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
