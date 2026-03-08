# CrossAssist

> Smart camera guidance for safer pedestrian crossings.

CrossAssist is an iOS assistive-vision app built for low-vision pedestrians. It uses the device's back camera (via ARKit), a YOLOv11n on-device object detection model, and real-time speech guidance to help users navigate intersections and urban environments safely.

---

## Screenshots

| Onboarding | Live Detection |
|---|---|
| ![Onboarding](Docs/onboarding.png) | ![Detection](Docs/detection.png) |

---

## Features

- **Real-time object detection** — YOLOv11n (80 COCO classes) running entirely on-device via Core ML + Vision
- **ARKit camera feed** — Live camera preview using `ARSCNView`, depth-ready for future LiDAR support
- **Bounding box overlay** — Colour-coded boxes with distance-estimated labels drawn on top of the camera
- **Distance estimation** — Height-based heuristic gives approximate distances per object class
- **Object tracking** — IoU-based multi-object tracker with EMA bounding-box smoothing (α = 0.4)
- **Voice guidance** — `@AppStorage`-persisted toggle (wired in next phase)
- **Haptic feedback** — `@AppStorage`-persisted toggle (wired in next phase)
- **Status bar** — Priority-driven: OBSTACLE STOP → Zebra Crossing → Searching → Path clear
- **Left panel** — Nearest person distance, traffic light state, danger object count with pulse animation
- **Onboarding screen** — Dark navy intro screen with mock phone animation and trust badges
- **Zero third-party dependencies** — Pure Apple frameworks only

---

## Architecture

```
CrossAssist/
├── App
│   ├── CrossAssistApp.swift        @main entry point
│   └── ContentView.swift           Onboarding gate via @AppStorage
│
├── Camera
│   ├── CameraFrame.swift           Value type wrapping CVPixelBuffer + timestamp
│   ├── CameraManager.swift         ARSession delegate, DROP frame strategy, @MainActor
│   └── CameraPreviewView.swift     UIViewRepresentable wrapping ARSCNView
│
├── Detection
│   ├── DetectionService.swift      Actor — loads yolo11n via generated class, runs VNCoreMLRequest
│   ├── DetectedObject.swift        Identifiable+Sendable struct for raw detections
│   ├── ObjectTracker.swift         Actor — IoU matching + EMA smoothing across frames
│   └── TrackedObject.swift         Identifiable+Sendable struct for tracked objects
│
├── Overlay
│   ├── OverlayView.swift           Canvas bounding boxes + SwiftUI label pills, DistanceEstimator
│   └── DistanceEstimator           (inside OverlayView.swift) height-based distance heuristic
│
├── UI
│   ├── OnboardingView.swift        S1 onboarding screen
│   ├── MainDetectionView.swift     Root detection screen, 6-layer ZStack
│   ├── TopBarView.swift            Voice/Haptic toggles + battery pill
│   ├── LeftPanelView.swift         3 status cards (person / traffic light / danger count)
│   ├── BottomStatusBar.swift       Priority-driven status message capsule
│   └── BottomActionBar.swift       STOP button + map/settings + static tab bar
│
└── Models
    └── yolo11n.mlpackage           Ultralytics YOLO11n, 80-class COCO, Core ML package
```

---

## Concurrency Model

The app is fully Swift 6-safe with zero `DispatchQueue` usage:

| Component | Isolation | Notes |
|---|---|---|
| `CameraManager` | `@MainActor` | Publishes `@Published` frames to SwiftUI |
| `DetectionService` | `actor` | Loaded via `@MainActor static func create()` |
| `ObjectTracker` | `actor` | Pure actor, no UI involvement |
| `CameraFrame` | `@unchecked Sendable` | `pixelBuffer` marked `nonisolated(unsafe)` |
| `DetectedObject` | `Sendable` | Value type, all fields Sendable |
| `TrackedObject` | `Sendable` | Value type, all fields Sendable |
| Frame drop strategy | `nonisolated(unsafe) var isProcessing` | Atomic bool, resets inside `Task { @MainActor }` |

---

## Detection Pipeline

```
ARSession.didUpdate(frame:)
    │  [DROP if busy]
    ▼
CameraFrame (pixelBuffer, timestamp)
    │  published on @MainActor
    ▼
DetectionService.detect(frame:)          ← actor, Vision + Core ML
    │  orientation: .right (portrait)
    │  VNCoreMLRequest → [VNRecognizedObjectObservation]
    │  confidence threshold: 0.30
    ▼
ObjectTracker.update(detections:)        ← actor, IoU matching
    │  EMA smoothing α = 0.4
    ▼
trackedObjects: [TrackedObject]          ← @State on MainActor
    │
    ├── OverlayView      (bounding boxes + distance labels)
    ├── LeftPanelView    (nearest person, danger count)
    └── BottomStatusBar  (priority status message)
```

---

## Bounding Box Colour Rules

| Object class | Colour | Label |
|---|---|---|
| car, truck, bus, motorcycle, bicycle | 🟠 `#F97316` orange | `VEHICLE` |
| person | 🔵 `#3B82F6` blue | `PERSON` |
| traffic light | 🟡 `#EAB308` yellow | `TRAFFIC LIGHT` |
| stop sign | 🔴 `#EF4444` red | class name |
| any object < 0.8 m | 🔴 `#EF4444` red override | `OBSTACLE • STOP` |
| everything else | ⬜ white | class name |

---

## Distance Estimation

No LiDAR required — distance is estimated from the **normalised bounding box height**:

| Class | Thresholds |
|---|---|
| `person` | >70% → 0.8 m · >45% → 1.5 m · >25% → 3 m · >12% → 6 m |
| `car / truck / bus` | >50% → 1.5 m · >30% → 3 m · >15% → 6 m · >8% → 10 m |
| `traffic light` | >30% → 5 m · >15% → 10 m |
| everything else | >40% → 1 m · >25% → 2 m · >12% → 4 m |

Distance label vocabulary: `STOP` (<0.8 m) · `very close` (<2 m) · `ahead` (<4 m) · `far ahead`

---

## Requirements

| Requirement | Value |
|---|---|
| Xcode | 26.2+ |
| iOS Deployment Target | iOS 26.2+ |
| Swift | Swift 6 |
| Device | iPhone (standard — no LiDAR required) |
| Frameworks | ARKit, Vision, Core ML, SwiftUI, Combine |

> **ARKit is required.** The app will not run in the iOS Simulator.

---

## Getting Started

```bash
# 1. Clone the repo
git clone https://github.com/shubhamjakhete/cross_assist.git
cd cross_assist

# 2. Open in Xcode
open CrossAssist.xcodeproj

# 3. Select your physical iPhone as the run destination
# 4. Build & Run (⌘R)
```

The YOLO model (`yolo11n.mlpackage`) is included in the repository under `CrossAssist/Models/`.
Xcode automatically compiles it to `.mlmodelc` during the build phase.

---

## Permissions

The app requires camera access. The permission description is set in build settings:

```
NSCameraUsageDescription =
"CrossAssist needs camera access to detect obstacles and guide your navigation"
```

---

## Roadmap

- [ ] **Phase 2** — AVSpeechSynthesizer voice guidance wired to detection events
- [ ] **Phase 3** — CoreHaptics feedback on OBSTACLE events
- [ ] **Phase 4** — Traffic light state classifier (red / green / unknown)
- [ ] **Phase 5** — Zebra crossing / crosswalk detector
- [ ] **Phase 6** — LiDAR depth integration (iPhone Pro) for accurate distance
- [ ] **Phase 7** — Settings screen (language, speech rate, sensitivity)
- [ ] **Phase 8** — History / session log screen

---

## Model

The included model is **Ultralytics YOLO11n** exported to Core ML:

| Property | Value |
|---|---|
| Architecture | YOLO11n |
| Classes | 80 (COCO) |
| Input size | 640 × 640 |
| Format | `.mlpackage` (Core ML) |
| Compute units | All (Neural Engine preferred) |
| NMS | Built into model |
| License | AGPL-3.0 ([ultralytics.com/license](https://ultralytics.com/license)) |

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Author

**Shubham Jakhete** — [@shubhamjakhete](https://github.com/shubhamjakhete)
