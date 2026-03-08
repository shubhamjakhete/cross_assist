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

    nonisolated let confidenceThreshold: Float = 0.30
    nonisolated let nmsIoUThreshold: Float = 0.45

    private var visionModel: VNCoreMLModel?

    // Private init — accepts an already-loaded VNCoreMLModel
    init(model: VNCoreMLModel) {
        self.visionModel = model
        print("✅ DetectionService ready — model injected")
    }

    // Static factory — must be called from MainActor context so the
    // @MainActor-isolated yolo11n generated class is safe to call.
    @MainActor
    static func create() throws -> DetectionService {
        print("🔵 DetectionService.create() starting...")
        let config = MLModelConfiguration()
        config.computeUnits = .all

        do {
            // yolo11n() is @MainActor-isolated — safe to call here
            let mlModel = try yolo11n(configuration: config)
            let vnModel = try VNCoreMLModel(for: mlModel.model)
            print("✅ Model loaded successfully via generated class")
            return DetectionService(model: vnModel)
        } catch {
            // Fallback: compile and load from bundle URL
            print("⚠️ Generated class failed, trying bundle URL: \(error)")
            guard let modelURL = Bundle.main.url(forResource: "yolo11n", withExtension: "mlpackage") else {
                print("❌ yolo11n.mlpackage not found in bundle")
                print("📦 mlpackage files: \(Bundle.main.urls(forResourcesWithExtension: "mlpackage", subdirectory: nil) ?? [])")
                print("📦 mlmodelc files: \(Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) ?? [])")
                throw DetectionError.modelNotFound
            }
            let compiledURL = try MLModel.compileModel(at: modelURL)
            let mlModel = try MLModel(contentsOf: compiledURL, configuration: config)
            let vnModel = try VNCoreMLModel(for: mlModel)
            print("✅ Model loaded successfully via bundle URL")
            return DetectionService(model: vnModel)
        }
    }

    func detect(frame: CameraFrame) async -> [DetectedObject] {
        guard let model = visionModel else {
            print("❌ visionModel is nil inside detect()")
            return []
        }

        print("🔍 detect() called")

        var results: [DetectedObject] = []

        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("❌ Vision request error: \(error)")
                return
            }
            guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                print("⚠️ No VNRecognizedObjectObservation results")
                return
            }
            print("✅ Got \(observations.count) raw observations")
            results = observations
                .filter { $0.confidence >= 0.30 }
                .map { obs in
                    DetectedObject(
                        id: UUID(),
                        label: obs.labels.first?.identifier ?? "unknown",
                        confidence: obs.confidence,
                        boundingBox: obs.boundingBox
                    )
                }
        }

        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.pixelBuffer,
            orientation: .right,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            print("❌ VNImageRequestHandler error: \(error)")
        }

        print("✅ detect() returning \(results.count) objects")
        return results
    }
}
