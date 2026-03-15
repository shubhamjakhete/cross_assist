//
//  DetectionService.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreML
import CoreVideo
import Vision

enum DetectionError: Error {
    case modelNotFound
    case modelLoadFailed
}

actor DetectionService {

    nonisolated let confidenceThreshold: Float = 0.40
    nonisolated let nmsIoUThreshold: Float = 0.45

    private var visionModel: VNCoreMLModel?
    /// Dedicated pedestrian-signal classifier (pedestrianSignal.mlpackage).
    /// Optional — if loading fails the service falls back to COCO-only mode.
    private var pedestrianVisionModel: VNCoreMLModel?
    /// Crosswalk / vulnerable-road-user detector (crosswalkDetection.mlpackage).
    /// Optional — service continues with the other two models if unavailable.
    private var crosswalkVisionModel: VNCoreMLModel?

    // Private init — accepts all three loaded vision models.
    init(model: VNCoreMLModel, pedestrianModel: VNCoreMLModel?, crosswalkModel: VNCoreMLModel?) {
        self.visionModel = model
        self.pedestrianVisionModel = pedestrianModel
        self.crosswalkVisionModel  = crosswalkModel
        let loaded = [pedestrianModel != nil ? "pedestrianSignal" : nil,
                      crosswalkModel   != nil ? "crosswalkDetection" : nil]
            .compactMap { $0 }.joined(separator: " + ")
        print("✅ DetectionService ready — yolo11n\(loaded.isEmpty ? "" : " + \(loaded)")")
    }

    // Static factory — must be called from @MainActor context because the
    // auto-generated Core ML classes (yolo11n, pedestrianSignal) are
    // @MainActor-isolated.
    @MainActor
    static func create() throws -> DetectionService {
        print("🔵 DetectionService.create() starting...")
        let config = MLModelConfiguration()
        config.computeUnits = .all

        // ── Model 1: yolo11n (required) ──────────────────────────────────
        let vnModel: VNCoreMLModel
        do {
            let mlModel = try yolo11n(configuration: config)
            vnModel = try VNCoreMLModel(for: mlModel.model)
            print("✅ yolo11n loaded via generated class")
        } catch {
            print("⚠️ yolo11n generated class failed, trying bundle URL: \(error)")
            guard let modelURL = Bundle.main.url(forResource: "yolo11n", withExtension: "mlpackage") else {
                print("❌ yolo11n.mlpackage not found in bundle")
                print("📦 mlpackage files: \(Bundle.main.urls(forResourcesWithExtension: "mlpackage", subdirectory: nil) ?? [])")
                print("📦 mlmodelc files: \(Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) ?? [])")
                throw DetectionError.modelNotFound
            }
            let compiledURL = try MLModel.compileModel(at: modelURL)
            let mlModel = try MLModel(contentsOf: compiledURL, configuration: config)
            vnModel = try VNCoreMLModel(for: mlModel)
            print("✅ yolo11n loaded via bundle URL")
        }

        // ── Model 2: pedestrianSignal (optional) ─────────────────────────
        var pedVNModel: VNCoreMLModel? = nil
        do {
            let pedModel = try pedestrianSignal(configuration: config)
            pedVNModel = try VNCoreMLModel(for: pedModel.model)
            print("✅ pedestrianSignal loaded successfully")
        } catch {
            print("⚠️ pedestrianSignal failed to load: \(error)")
        }

        // ── Model 3: crosswalkDetection (optional) ────────────────────────
        var cwVNModel: VNCoreMLModel? = nil
        do {
            let cwModel = try crosswalkDetection(configuration: config)
            cwVNModel = try VNCoreMLModel(for: cwModel.model)
            print("✅ crosswalkDetection loaded successfully")
        } catch {
            print("⚠️ crosswalkDetection failed to load: \(error)")
        }

        return DetectionService(model: vnModel, pedestrianModel: pedVNModel, crosswalkModel: cwVNModel)
    }

    func detect(frame: CameraFrame) async -> [DetectedObject] {
        guard let model = visionModel else {
            print("❌ visionModel is nil inside detect()")
            return []
        }

        print("🔍 detect() called")

        // ── Model 1: yolo11n — COCO object detection ─────────────────────

        // Pedestrian-safety classes shown at normal confidence threshold.
        let alwaysShow: Set<String> = [
            "person", "bicycle", "car", "motorcycle",
            "bus", "truck", "traffic light", "stop sign"
        ]
        // Path-obstacle classes only shown when confidence is high enough to
        // avoid false positives on cluttered backgrounds.
        let obstacleLabels: Set<String> = ["bench", "chair", "couch", "sofa"]
        let obstacleThreshold: Float = 0.55

        var yoloResults: [DetectedObject] = []

        let yoloRequest = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("❌ yolo11n Vision request error: \(error)")
                return
            }
            guard let observations = request.results as? [VNRecognizedObjectObservation] else { return }
            print("✅ yolo11n: \(observations.count) raw observations")

            var filtered: [DetectedObject] = []
            for obs in observations {
                guard obs.confidence >= 0.40 else { continue }
                let raw = obs.labels.first?.identifier.lowercased() ?? ""

                if alwaysShow.contains(raw) {
                    let bbox = obs.boundingBox

                    // ── Person-specific false-positive filters ──────────────
                    // Walk-signal figures are square; real pedestrians are tall.
                    if raw == "person" {
                        let aspectRatio = bbox.height / bbox.width
                        guard aspectRatio > 1.4 else { continue }
                        guard (bbox.width * bbox.height) >= 0.005 else { continue }
                    }
                    // ────────────────────────────────────────────────────────

                    filtered.append(DetectedObject(
                        id: UUID(),
                        label: canonicalLabel(raw),
                        confidence: obs.confidence,
                        boundingBox: bbox
                    ))
                } else if obstacleLabels.contains(raw), obs.confidence >= obstacleThreshold {
                    filtered.append(DetectedObject(
                        id: UUID(),
                        label: "obstacle",
                        confidence: obs.confidence,
                        boundingBox: obs.boundingBox
                    ))
                }
                // All other COCO classes are discarded completely.
            }
            yoloResults = filtered
        }
        yoloRequest.imageCropAndScaleOption = .scaleFill

        // ── Model 2: pedestrianSignal — walk / don't walk classifier ─────

        var pedResults: [DetectedObject] = []

        var requests: [VNRequest] = [yoloRequest]

        if let pedModel = pedestrianVisionModel {
            let pedRequest = VNCoreMLRequest(model: pedModel) { request, error in
                if let error = error {
                    print("❌ pedestrianSignal Vision request error: \(error)")
                    return
                }
                guard let observations = request.results as? [VNRecognizedObjectObservation] else { return }
                print("✅ pedestrianSignal: \(observations.count) raw observations")

                var filtered: [DetectedObject] = []
                for obs in observations {
                    guard obs.confidence >= 0.40 else { continue }
                    let raw = obs.labels.first?.identifier.lowercased() ?? ""
                    filtered.append(DetectedObject(
                        id: UUID(),
                        label: pedestrianLabel(raw),
                        confidence: obs.confidence,
                        boundingBox: obs.boundingBox
                    ))
                }
                pedResults = filtered
            }
            pedRequest.imageCropAndScaleOption = .scaleFill
            requests.append(pedRequest)
        }

        // ── Model 3: crosswalkDetection — crosswalk + vulnerable road users ──

        var crosswalkResults: [DetectedObject] = []

        if let cwModel = crosswalkVisionModel {
            let cwRequest = VNCoreMLRequest(model: cwModel) { request, error in
                if let error = error {
                    print("❌ crosswalkDetection Vision request error: \(error)")
                    return
                }
                guard let observations = request.results as? [VNRecognizedObjectObservation] else { return }
                print("✅ crosswalkDetection: \(observations.count) raw observations")

                var filtered: [DetectedObject] = []
                for obs in observations {
                    guard obs.confidence >= 0.35 else { continue }
                    let raw = obs.labels.first?.identifier.lowercased() ?? ""
                    // Only emit labels that aren't duplicates of yolo11n classes.
                    guard let label = crosswalkLabel(raw) else { continue }
                    filtered.append(DetectedObject(
                        id: UUID(),
                        label: label,
                        confidence: obs.confidence,
                        boundingBox: obs.boundingBox
                    ))
                }
                crosswalkResults = filtered
            }
            cwRequest.imageCropAndScaleOption = .scaleFill
            requests.append(cwRequest)
        }

        // ── Run all three requests on the same handler in one pass ────────

        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.pixelBuffer,
            orientation: .right,
            options: [:]
        )

        do {
            try handler.perform(requests)
        } catch {
            print("❌ VNImageRequestHandler error: \(error)")
        }

        let merged = yoloResults + pedResults + crosswalkResults
        print("✅ detect() returning \(merged.count) objects (\(yoloResults.count) COCO + \(pedResults.count) signal + \(crosswalkResults.count) crosswalk)")
        return merged
    }
}

// MARK: - Label remapping

/// Maps raw COCO class names to the canonical labels used throughout the app.
/// Groups semantically identical classes (car / motorcycle / bus / truck → "vehicle")
/// so the rest of the UI only needs to handle a small, well-known set of strings.
private func canonicalLabel(_ raw: String) -> String {
    switch raw {
    case "car", "motorcycle", "bus", "truck": return "vehicle"
    case "person":        return "person"
    case "bicycle":       return "bicycle"
    case "traffic light": return "traffic light"
    case "stop sign":     return "stop sign"
    default:              return raw   // bench/chair/couch are already remapped to "obstacle" by the caller
    }
}

/// Maps raw pedestrianSignal model class names to display labels.
/// Classes: 0=green, 1=pedestrian traffic light, 2=red, 3=signal-light
private func pedestrianLabel(_ raw: String) -> String {
    switch raw {
    case "green":                       return "GREEN LIGHT"
    case "pedestrian traffic light":    return "WALK SIGNAL"
    case "red":                         return "RED LIGHT"
    case "signal-light":                return "SIGNAL"
    default:                            return raw
    }
}

/// Maps raw crosswalkDetection class names to display labels.
/// Returns nil for classes that duplicate yolo11n (cars, motorcycle, truck).
///
/// Classes:
///   0 = cars               → nil (skip)
///   1 = crosswalk          → "CROSSWALK"
///   2 = green_traffic_light → "GREEN LIGHT"
///   3 = motorcycle         → nil (skip)
///   4 = red_traffic_light  → "RED LIGHT"
///   5 = truck              → nil (skip)
///   6 = wheelchair_road_user → "WHEELCHAIR USER"
///   7 = white_cane_user    → "CANE USER"
private func crosswalkLabel(_ raw: String) -> String? {
    switch raw {
    case "crosswalk":            return "CROSSWALK"
    case "green_traffic_light":  return "GREEN LIGHT"
    case "red_traffic_light":    return "RED LIGHT"
    case "wheelchair_road_user": return "WHEELCHAIR USER"
    case "white_cane_user":      return "CANE USER"
    case "cars", "motorcycle", "truck": return nil  // handled by yolo11n
    default:                     return nil
    }
}
