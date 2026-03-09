//
//  OverlayView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import SwiftUI

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Overlay Helpers

private let vehicleLabels: Set<String> = ["car", "truck", "bus", "motorcycle", "bicycle"]

private func boxColor(for label: String, distance: Float?) -> Color {
    if let d = distance, d < 0.8 { return Color(hex: "EF4444") }
    switch label {
    case _ where vehicleLabels.contains(label): return Color(hex: "F97316")
    case "person":                               return Color(hex: "3B82F6")
    case "traffic light":                        return Color(hex: "EAB308")
    case "stop sign":                            return Color(hex: "EF4444")
    default:                                     return .white
    }
}

private func displayLabel(for label: String) -> String {
    switch label {
    case _ where vehicleLabels.contains(label): return "VEHICLE"
    case "traffic light":                       return "TRAFFIC LIGHT"
    default:                                    return label.uppercased()
    }
}

private func pillText(label: String, distance: Float?) -> String {
    if let d = distance, d < 0.8 { return "OBSTACLE • STOP" }
    let base = displayLabel(for: label)
    guard let d = distance else { return base }
    return "\(base) • \(String(format: "%.1fm", d))"
}

// MARK: - Coordinate Conversion

private func visionToSwiftUI(box: CGRect, in size: CGSize) -> CGRect {
    let x = box.minX  * size.width
    let y = (1.0 - box.maxY) * size.height
    let w = box.width  * size.width
    let h = box.height * size.height
    return CGRect(x: x, y: y, width: w, height: h)
}

// MARK: - OverlayView

struct OverlayView: View {
    let trackedObjects: [TrackedObject]
    let viewSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Bounding boxes drawn with Canvas for performance
            Canvas { ctx, size in
                for obj in trackedObjects {
                    let color = boxColor(for: obj.label, distance: obj.distanceMeters)
                    let rect  = visionToSwiftUI(box: obj.boundingBox, in: size)
                    let path  = Path(roundedRect: rect, cornerRadius: 12)
                    ctx.stroke(path, with: .color(color), lineWidth: 2.5)
                }
            }

            // Label pills as SwiftUI views for rich text rendering.
            // .id(text) forces SwiftUI to treat every text change as a brand-new
            // view, so .transition(.opacity) cross-fades old → new instead of
            // snapping to the updated string.
            ForEach(trackedObjects) { obj in
                let color = boxColor(for: obj.label, distance: obj.distanceMeters)
                let text  = pillText(label: obj.label, distance: obj.distanceMeters)
                let rect  = visionToSwiftUI(box: obj.boundingBox, in: viewSize)

                Text(text)
                    .id(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.90), in: Capsule())
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: text)
                    .position(
                        x: rect.minX + pillWidth(text: text) / 2 + 4,
                        y: rect.minY + 14
                    )
            }
        }
        .animation(.easeInOut(duration: 0.12), value: trackedObjects.map { $0.boundingBox.origin.x })
        .allowsHitTesting(false)
    }

    // Approximate pill width so the label stays inside the screen
    private func pillWidth(text: String) -> CGFloat {
        CGFloat(text.count) * 7.5 + 16
    }
}

// MARK: - Preview

#Preview {
    let fakeObjects: [TrackedObject] = [
        TrackedObject(id: 0, label: "person",    confidence: 0.92,
                      boundingBox: CGRect(x: 0.10, y: 0.20, width: 0.15, height: 0.45),
                      distanceMeters: 1.2),
        TrackedObject(id: 1, label: "car",       confidence: 0.88,
                      boundingBox: CGRect(x: 0.50, y: 0.30, width: 0.35, height: 0.30),
                      distanceMeters: 4.5),
        TrackedObject(id: 2, label: "stop sign", confidence: 0.75,
                      boundingBox: CGRect(x: 0.70, y: 0.60, width: 0.12, height: 0.12),
                      distanceMeters: 0.6),
    ]
    return ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        GeometryReader { geo in
            OverlayView(trackedObjects: fakeObjects, viewSize: geo.size)
        }
    }
}
