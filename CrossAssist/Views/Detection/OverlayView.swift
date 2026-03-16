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

/// Bounding-box stroke colour per canonical label.
/// Critical proximity (< 0.8 m) overrides all colours to red.
private func boxColor(for label: String, distance: Float?) -> Color {
    if let d = distance, d < 0.8 { return Color(hex: "EF4444") }
    switch label {
    // yolo11n canonical labels
    case "person":           return Color(hex: "3B82F6")  // blue
    case "vehicle":          return Color(hex: "EF4444")  // red
    case "bicycle":          return Color(hex: "A855F7")  // purple
    case "traffic light":    return Color(hex: "EAB308")  // yellow
    case "stop sign":        return Color(hex: "F97316")  // orange
    case "obstacle":         return Color(hex: "6B7280")  // gray
    // pedestrianSignal model labels
    case "GREEN LIGHT":      return Color(hex: "22C55E")  // green
    case "RED LIGHT":        return Color(hex: "EF4444")  // red
    case "WALK SIGNAL":      return Color(hex: "3B82F6")  // blue
    case "SIGNAL":           return Color(hex: "EAB308")  // yellow
    // crosswalkDetection model labels
    case "CROSSWALK":        return Color(hex: "3B82F6")  // blue
    case "WHEELCHAIR USER":  return Color(hex: "8B5CF6")  // purple
    case "CANE USER":        return .white
    default:                 return .white
    }
}

/// User-facing display name for a canonical label.
private func displayLabel(for label: String) -> String {
    switch label {
    case "person":        return "PERSON"
    case "vehicle":       return "VEHICLE"
    case "bicycle":       return "BICYCLE"
    case "traffic light": return "TRAFFIC LIGHT"
    case "stop sign":     return "STOP SIGN"
    case "obstacle":      return "OBSTACLE"
    default:              return label.uppercased()
    }
}

private func pillText(label: String, distance: Float?, trafficState: TrafficLightState?) -> String {
    // Traffic light: show the detected colour instead of distance
    if label.lowercased().contains("traffic light"), let state = trafficState {
        switch state.color {
        case .red:     return "🔴 RED"
        case .yellow:  return "🟡 YELLOW"
        case .green:   return "🟢 GREEN"
        case .unknown: return "⚫ LIGHT"
        }
    }
    if let d = distance, d < 0.8 { return "OBSTACLE • STOP" }
    let base = displayLabel(for: label)
    guard let d = distance else { return base }
    return "\(base) • \(String(format: "%.1fm", d))"
}

/// Pill background colour.  For traffic lights this is state-driven;
/// for everything else it falls through to `boxColor`.
private func pillBgColor(for label: String, trafficState: TrafficLightState?, distance: Float?) -> Color {
    if label.lowercased().contains("traffic light"), let state = trafficState {
        switch state.color {
        case .red:     return .red
        case .yellow:  return Color(hex: "EAB308")
        case .green:   return .green
        case .unknown: return Color(hex: "EAB308")
        }
    }
    return boxColor(for: label, distance: distance)
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
            // Bounding boxes drawn with Canvas for performance.
            // CROSSWALK gets a dashed blue stroke (less intrusive, road-marking feel).
            // All other labels get the standard solid stroke.
            Canvas { ctx, size in
                for obj in trackedObjects {
                    let color = boxColor(for: obj.label, distance: obj.distanceMeters)
                    let rect  = visionToSwiftUI(box: obj.boundingBox, in: size)
                    if obj.label == "CROSSWALK" {
                        let path = Path(roundedRect: rect, cornerRadius: 8)
                        ctx.stroke(path,
                                   with: .color(color.opacity(0.7)),
                                   style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    } else {
                        let path = Path(roundedRect: rect, cornerRadius: 12)
                        ctx.stroke(path, with: .color(color), lineWidth: 2.5)
                    }
                }
            }

            // Label pills as SwiftUI views for rich text rendering.
            // .id(text) forces SwiftUI to treat every text change as a brand-new
            // view, so .transition(.opacity) cross-fades old → new instead of
            // snapping to the updated string.
            ForEach(trackedObjects) { obj in
                let pillBg = pillBgColor(for: obj.label,
                                         trafficState: obj.trafficLightState,
                                         distance: obj.distanceMeters)
                let text   = pillText(label: obj.label,
                                      distance: obj.distanceMeters,
                                      trafficState: obj.trafficLightState)
                let rect   = visionToSwiftUI(box: obj.boundingBox, in: viewSize)

                Text(text)
                    .id(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(pillBg.opacity(0.90), in: Capsule())
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: text)
                    .position(
                        // CROSSWALK covers the full ground area — center the pill
                        // horizontally so it doesn't crowd the left edge.
                        x: obj.label == "CROSSWALK"
                            ? rect.midX
                            : rect.minX + pillWidth(text: text) / 2 + 4,
                        // Clamp to 100 pt from the top so pills on partially
                        // off-screen boxes (e.g. overhead traffic lights) never
                        // overlap the top bar UI elements.
                        y: max(rect.minY + 14, 100)
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
