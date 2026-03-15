# CrossAssist

> Smart camera guidance for safer pedestrian crossings.

CrossAssist is an iOS assistive-vision app built for low-vision pedestrians. It uses the device's back camera (via ARKit), three on-device ML models running in parallel, and real-time visual guidance to help users navigate intersections and urban environments safely.

---

## Features

- **Three parallel YOLO models** — yolo11n (80-class COCO), pedestrianSignal (4-class), and crosswalkDetection (8-class) run on every frame through a single `VNImageRequestHandler` pass
- **Traffic light colour classification** — HSV pixel analysis on the detected bounding box identifies RED / YELLOW / GREEN bulbs without a dedicated model
- **Walk-signal countdown detection** — Vision OCR crops the region to the right of the signal panel (where the countdown number lives) and maps the digit to a crossing recommendation: CROSS NOW / HURRY / WAIT / next signal
- **Crosswalk detection + deduplication** — the crosswalkDetection model fires per stripe; ObjectTracker merges all overlapping boxes into one union bounding box before display
- **On-device depth estimation** — Depth Anything V2 (518 × 518) runs every 8th frame in a detached background task; results enrich `distanceMeters` on each tracked object
- **Bounding-box overlay** — colour-coded dashed/solid boxes with distance labels; CROSSWALK gets a dashed blue road-marking style
- **Priority status bar** — 10-tier priority: critical proximity → timer too-late → wait → hurry → safe-to-cross → dangerous → safe walk → crosswalk → scanning → clear
- **Left panel cards** — nearest person distance, walk-signal countdown (large digit + action label), danger object count with pulse animation
- **Crossing hint banner** — auto-dismissed blue banner when a crosswalk is detected; links to CrossingGuidanceView
- **Multi-screen navigation** — Onboarding → Accessibility Setup → Home → Detection → Crossing Guidance → Emergency → Settings
- **SOS emergency view** — call / share location / loud siren; long-press STOP or tap SOS pill
- **ARKit camera feed** — Live preview via `ARSCNView`, frame-drop strategy to keep detection latency low
- **Voice / Haptic toggles** — `@AppStorage`-persisted; ready to wire to `AVSpeechSynthesizer` and CoreHaptics
- **Zero third-party dependencies** — Pure Apple frameworks only (ARKit, Vision, Core ML, SwiftUI, Combine, MapKit)

---

## Architecture

```
CrossAssist/
├── App
│   ├── CrossAssistApp.swift          @main entry point
│   └── ContentView.swift             Onboarding gate via @AppStorage
│
├── Models
│   ├── CameraFrame.swift             Value type wrapping CVPixelBuffer + timestamp
│   ├── DetectedObject.swift          Identifiable+Sendable struct for raw detections
│   └── TrackedObject.swift           Identifiable+Sendable struct (distance, state, rec)
│
├── Services
│   ├── CameraManager.swift           ARSession delegate, DROP frame strategy, @MainActor
│   ├── DetectionService.swift        Actor — 3 VNCoreMLRequests in one handler pass
│   ├── ObjectTracker.swift           Actor — IoU matching, EMA smoothing, crosswalk dedup
│   ├── DistanceEstimator.swift       Height-based distance heuristic (no LiDAR)
│   ├── DepthEstimationService.swift  Actor — Depth Anything V2, every 8th frame
│   ├── TrafficLightColorClassifier.swift  nonisolated static HSV pixel analyser
│   └── WalkSignalTimerService.swift  nonisolated static Vision OCR pipeline
│
├── Views
│   ├── App
│   │   └── CameraPreviewView.swift   UIViewRepresentable wrapping ARSCNView
│   ├── Detection
│   │   ├── MainDetectionView.swift   Root detection screen, 6-layer ZStack
│   │   ├── OverlayView.swift         Canvas boxes + SwiftUI label pills
│   │   ├── TopBarView.swift          Voice/Haptic toggles + SOS pill
│   │   ├── LeftPanelView.swift       3 status cards with debounced updates
│   │   ├── BottomStatusBar.swift     Priority-driven status capsule (10 tiers)
│   │   └── BottomActionBar.swift     STOP button + map/settings + tab bar
│   ├── Shared
│   │   └── PlaceholderView.swift     "Coming soon" screen for unbuilt routes
│   ├── OnboardingView.swift          S1 dark-navy intro screen
│   ├── AccessibilitySetupView.swift  S2 accessibility configuration
│   ├── HomeView.swift                S3 home dashboard
│   ├── CrossingGuidanceView.swift    S5 live crossing guidance + MapKit
│   ├── EmergencyView.swift           S6 SOS / call / location share
│   └── SettingsView.swift            S7 preferences + emergency contact
│
└── Models (ML)
    ├── yolo11n.mlpackage             Ultralytics YOLO11n — 80-class COCO
    ├── pedestrianSignal.mlpackage    4-class walk/don't-walk signal classifier
    ├── crosswalkDetection.mlpackage  8-class crosswalk + vulnerable road user detector
    └── DepthAnythingV2.mlpackage     Monocular depth estimation (518 × 518)
```

---

## Concurrency Model

The app is fully Swift 6-safe with zero `DispatchQueue` usage:

| Component | Isolation | Notes |
|---|---|---|
| `CameraManager` | `@MainActor` | Publishes `@Published` frames to SwiftUI |
| `DetectionService` | `actor` | Loaded via `@MainActor static func create()` |
| `ObjectTracker` | `actor` | Pure actor, no UI involvement |
| `DepthEstimationService` | `actor` | Runs on `.utility` detached task every 8th frame |
| `TrafficLightColorClassifier` | `nonisolated static` | No actor, pure pixel math |
| `WalkSignalTimerService` | `nonisolated static` | Vision OCR with DispatchSemaphore fence |
| `CameraFrame` | `@unchecked Sendable` | `pixelBuffer` marked `nonisolated(unsafe)` |
| `TrackedObject` | `Sendable` | Value type; `WalkSignalRecommendation` Equatable+Sendable |
| Frame drop strategy | `nonisolated(unsafe) var isProcessing` | Resets inside `Task { @MainActor }` |

---

## Detection Pipeline

```
ARSession.didUpdate(frame:)
    │  [DROP if busy]
    ▼
CameraFrame (pixelBuffer, timestamp)
    │  published on @MainActor
    ▼
DetectionService.detect(frame:)            ← actor
    │  Single VNImageRequestHandler pass:
    │  ├── yolo11n request          (confidence ≥ 0.40, 8 COCO classes kept)
    │  ├── pedestrianSignal request (confidence ≥ 0.40, all 4 classes)
    │  └── crosswalkDetection request (confidence ≥ 0.35, 5 of 8 classes)
    │  Results merged: [DetectedObject]
    ▼
ObjectTracker.update(detections:frame:)    ← actor
    │  IoU matching (threshold ≥ 0.25) + EMA smoothing (α = 0.25)
    │  Traffic light HSV classification (TrafficLightColorClassifier)
    │  Walk-signal OCR (WalkSignalTimerService) — pedestrianSignal labels only
    │  CROSSWALK deduplication — union hull → single bounding box
    │  Age filter: person ≥ 8 frames, others ≥ 1 frame
    ▼
trackedObjects: [TrackedObject]            ← @State on MainActor
    │
    ├── OverlayView          (bounding boxes + distance labels)
    ├── LeftPanelView        (person distance / signal countdown / danger count)
    └── BottomStatusBar      (10-tier priority status message)
    │
    └── Every 8th frame → DepthEstimationService.estimateDepth()   ← detached task
            │  Depth Anything V2 (518 × 518), ImageNet-normalised input
            ▼
        enriched distanceMeters on each TrackedObject
```

---

## Models

### yolo11n — General Object Detection

| Property | Value |
|---|---|
| Architecture | YOLO11n |
| Source | Ultralytics |
| Classes | 80 (COCO); app filters to 8 safety-critical + 3 obstacle classes |
| Input size | 640 × 640 |
| Confidence threshold | 0.40 |
| Format | `.mlpackage` (Core ML) |
| Compute units | All (Neural Engine preferred) |
| License | AGPL-3.0 ([ultralytics.com/license](https://ultralytics.com/license)) |

### pedestrianSignal — Walk / Don't Walk Classifier

| Property | Value |
|---|---|
| Classes | 4: green · pedestrian traffic light · red · signal-light |
| App labels | `GREEN LIGHT` · `WALK SIGNAL` · `RED LIGHT` · `SIGNAL` |
| Confidence threshold | 0.40 |
| Format | `.mlpackage` (Core ML) |
| Usage | Identifies pedestrian signal state; triggers Vision OCR for countdown |

### crosswalkDetection — Crosswalk & Vulnerable Road User Detector

| Property | Value |
|---|---|
| Classes | 8 total; 5 used: crosswalk · green/red traffic light · wheelchair user · cane user |
| App labels | `CROSSWALK` · `GREEN LIGHT` · `RED LIGHT` · `WHEELCHAIR USER` · `CANE USER` |
| Confidence threshold | 0.35 |
| Format | `.mlpackage` (Core ML) |
| Usage | Crosswalk box → deduped to single union hull; triggers crossing hint banner |

### DepthAnythingV2 — Monocular Depth Estimation

| Property | Value |
|---|---|
| Architecture | Depth Anything V2 |
| Input | `pixel_values` — (1, 3, 518, 518) float32, ImageNet-normalised |
| Output | `unsqueeze` — (1, 1, 518, 518) relative inverse depth |
| Compute units | All |
| Frequency | Every 8th frame (background detached task) |
| Usage | Enriches `distanceMeters` on each TrackedObject; falls back to height heuristic |

---

## Bounding Box Colour Rules

| Label / source | Colour | Style |
|---|---|---|
| `person` (yolo11n) | 🔵 `#3B82F6` blue | Solid |
| `vehicle` (yolo11n) | 🔴 `#EF4444` red | Solid |
| `bicycle` (yolo11n) | 🟣 `#A855F7` purple | Solid |
| `traffic light` (yolo11n) | 🟡 `#EAB308` yellow | Solid |
| `stop sign` (yolo11n) | 🟠 `#F97316` orange | Solid |
| `obstacle` (yolo11n) | ⬜ `#6B7280` gray | Solid |
| `GREEN LIGHT` / `WALK SIGNAL` | 🔵 `#3B82F6` / 🟢 `#22C55E` | Solid |
| `RED LIGHT` | 🔴 `#EF4444` red | Solid |
| `SIGNAL` | 🟡 `#EAB308` yellow | Solid |
| `CROSSWALK` | 🔵 `#3B82F6` blue @ 70% | **Dashed** `[8, 4]` — road-marking style |
| `WHEELCHAIR USER` | 🟣 `#8B5CF6` purple | Solid |
| `CANE USER` | ⬜ white | Solid |
| Any object < 0.8 m | 🔴 `#EF4444` red override | Solid |

---

## Distance Estimation

Heuristic (fallback, no ML): distance estimated from normalised bounding-box height via pinhole camera model (vertical FOV ≈ 55°, real-world heights per class).

Depth Anything V2 (primary, when available): relative inverse depth sampled at bbox centre, mapped to metric via `scale / (depth + shift)` calibration.

---

## Requirements

| Requirement | Value |
|---|---|
| Xcode | 26.2+ |
| iOS Deployment Target | iOS 26.2+ |
| Swift | Swift 6 |
| Device | iPhone (standard — no LiDAR required) |
| Frameworks | ARKit, Vision, Core ML, SwiftUI, Combine, MapKit, AVFoundation |

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

All four ML models (`yolo11n`, `pedestrianSignal`, `crosswalkDetection`, `DepthAnythingV2`) are included under `CrossAssist/Models/`. Xcode compiles them to `.mlmodelc` automatically during the build phase.

---

## Permissions

```
NSCameraUsageDescription =
"CrossAssist needs camera access to detect obstacles and guide your navigation"
```

---

## Roadmap

- [ ] **Phase 2** — AVSpeechSynthesizer voice guidance wired to detection events
- [ ] **Phase 3** — CoreHaptics feedback on OBSTACLE / critical-proximity events
- [x] **Phase 4** — Traffic light state classifier (RED / YELLOW / GREEN) — HSV pixel analysis + pedestrianSignal model
- [x] **Phase 5** — Zebra crossing / crosswalk detector — crosswalkDetection model with stripe deduplication
- [x] **Phase 6** — Depth estimation — Depth Anything V2 (monocular ML depth, no LiDAR required)
- [x] **Phase 7** — Settings screen — language, speech rate, sensitivity, emergency contact
- [ ] **Phase 8** — History / session log screen
- [ ] **Phase 9** — Walk-signal countdown accuracy improvement (larger OCR crop, multi-frame averaging)
- [ ] **Phase 10** — Firebase emergency location sharing (EmergencyView stub ready)

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Author

**Shubham Jakhete** — [@shubhamjakhete](https://github.com/shubhamjakhete)
