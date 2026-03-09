//
//  DepthEstimationService.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import CoreML
import CoreVideo
import UIKit

actor DepthEstimationService {

    private var model: DepthAnythingV2?
    // Reused across frames — avoids allocating a new CIContext every call
    private nonisolated let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Private init accepts an already-loaded, @MainActor-constructed model
    init(model: DepthAnythingV2) {
        self.model = model
        print("✅ DepthEstimationService ready")
    }

    // Static factory — called from @MainActor so the generated DepthAnythingV2
    // class (implicitly @MainActor-isolated) can be instantiated safely.
    @MainActor
    static func create() throws -> DepthEstimationService {
        print("DepthEstimationService.create() starting...")
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let model = try DepthAnythingV2(configuration: config)
        print("✅ DepthAnythingV2 model loaded")
        return DepthEstimationService(model: model)
    }

    // MARK: - Public API

    /// Returns a metric depth in metres sampled at the bounding-box centre.
    /// `boundingBox` uses Vision normalized coords (bottom-left origin, 0–1 range).
    func estimateDepth(
        pixelBuffer: CVPixelBuffer,
        boundingBox: CGRect
    ) async -> Float? {
        guard let model else { return nil }

        guard let resized = resizePixelBuffer(pixelBuffer, width: 518, height: 518) else {
            return nil
        }
        guard let inputArray = pixelBufferToMLMultiArray(resized) else {
            return nil
        }

        // Model methods are @MainActor-isolated — hop there for inference
        let depthArray = await MainActor.run {
            let input = DepthAnythingV2Input(pixel_values: inputArray)
            guard let output = try? model.prediction(input: input) else {
                return nil as MLMultiArray?
            }
            return output.featureValue(for: "unsqueeze")?.multiArrayValue
        }

        guard let depthArray else { return nil }

        // Convert Vision coords (bottom-left origin) → image coords (top-left origin)
        let centerX = boundingBox.midX
        let centerY = 1.0 - boundingBox.midY

        let pixelX = max(0, min(517, Int(centerX * 518)))
        let pixelY = max(0, min(517, Int(centerY * 518)))

        // Depth array shape: (1, 1, 518, 518)
        let index    = pixelY * 518 + pixelX
        let rawDepth = depthArray[index].floatValue

        return depthToMeters(rawDepth)
    }

    // MARK: - Private Helpers

    /// Convert relative inverse depth (higher = closer) to metric metres.
    private nonisolated func depthToMeters(_ relativeDepth: Float) -> Float {
        let scale: Float = 5.0
        let shift: Float = 0.1
        guard relativeDepth > 0 else { return 20.0 }
        let metric = scale / (relativeDepth + shift)
        return min(max(metric, 0.3), 30.0)
    }

    /// Resize a CVPixelBuffer to `width × height` using CIContext.
    private nonisolated func resizePixelBuffer(
        _ buffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let scaleX  = CGFloat(width)  / CGFloat(CVPixelBufferGetWidth(buffer))
        let scaleY  = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(buffer))
        let scaled  = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var output: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &output)
        guard let output else { return nil }

        ciContext.render(scaled, to: output)
        return output
    }

    /// Convert a 32BGRA CVPixelBuffer (518×518) to an MLMultiArray of shape
    /// (1, 3, 518, 518) with ImageNet normalisation applied.
    /// Uses raw pointer arithmetic instead of subscript indexing — ~10× faster.
    private nonisolated func pixelBufferToMLMultiArray(
        _ buffer: CVPixelBuffer
    ) -> MLMultiArray? {
        guard let array = try? MLMultiArray(shape: [1, 3, 518, 518], dataType: .float32) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let width       = 518
        let height      = 518
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let ptr         = baseAddress.assumingMemoryBound(to: UInt8.self)
        let totalPixels = width * height

        // Direct pointer access to the three channel planes
        let rPtr = array.dataPointer.assumingMemoryBound(to: Float.self)
        let gPtr = rPtr.advanced(by: totalPixels)
        let bPtr = gPtr.advanced(by: totalPixels)

        let mean:  [Float] = [0.485, 0.456, 0.406]
        let std:   [Float] = [0.229, 0.224, 0.225]
        let scale: Float   = 1.0 / 255.0

        for y in 0..<height {
            let rowPtr    = ptr.advanced(by: y * bytesPerRow)
            let rowOffset = y * width
            for x in 0..<width {
                let p = rowPtr.advanced(by: x * 4)
                let b = Float(p[0]) * scale
                let g = Float(p[1]) * scale
                let r = Float(p[2]) * scale
                rPtr[rowOffset + x] = (r - mean[0]) / std[0]
                gPtr[rowOffset + x] = (g - mean[1]) / std[1]
                bPtr[rowOffset + x] = (b - mean[2]) / std[2]
            }
        }

        return array
    }
}
