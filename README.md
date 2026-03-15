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

## Algorithms & Math

### 1. Distance Estimation — Pinhole Camera Model
*`Services/DistanceEstimator.swift`*

$$d = \frac{h_{\text{real}}}{2 \cdot \tan\!\left(\dfrac{\text{vFOV}}{2}\right) \cdot r_{\text{box}}}$$

| Symbol | Description | Value |
|---|---|---|
| $d$ | Estimated distance (metres) | output, clamped 0.3 – 50 m |
| $h_{\text{real}}$ | Known real-world object height | person = 1.7 m · car = 1.5 m · bus = 3.2 m … |
| $\text{vFOV}$ | Vertical field of view (iPhone 13 portrait) | 55° |
| $r_{\text{box}}$ | Bounding-box height as fraction of frame | 0 – 1 (Vision normalised) |

---

### 2. Depth Anything V2 — Inverse Depth to Metric
*`Services/DepthEstimationService.swift`*

$$d_{\text{metric}} = \frac{\text{scale}}{\text{relativeDepth} + \text{shift}}$$

| Symbol | Description | Value |
|---|---|---|
| $d_{\text{metric}}$ | Metric depth (metres) | output, clamped 0.3 – 30 m |
| $\text{relativeDepth}$ | Raw model output (higher = closer to camera) | 0 – 1 (relative) |
| $\text{scale}$ | Empirical calibration constant | 5.0 |
| $\text{shift}$ | Prevents division by zero near camera | 0.1 |

The model outputs **relative inverse depth** — pixel values closer to 1 are nearer. The calibration converts to approximate metric depth for iPhone 13.

---

### 3. Object Tracking — IoU (Intersection over Union)
*`Services/ObjectTracker.swift`*

$$\text{IoU}(A, B) = \frac{|A \cap B|}{|A \cup B|} = \frac{|A \cap B|}{|A| + |B| - |A \cap B|}$$

$$|A \cap B| = \max(0,\; x_{\max}^{\min} - x_{\min}^{\max}) \;\times\; \max(0,\; y_{\max}^{\min} - y_{\min}^{\max})$$

Where $x_{\max}^{\min}$ means $\min(\max x_A, \max x_B)$ and $x_{\min}^{\max}$ means $\max(\min x_A, \min x_B)$.

**Threshold:** IoU ≥ 0.25 → same object (track is updated); IoU < 0.25 → new object (new track created).

---

### 4. Bounding Box Smoothing — EMA (Exponential Moving Average)
*`Services/ObjectTracker.swift`*

$$\hat{b}_t = \alpha \cdot b_t + (1 - \alpha) \cdot \hat{b}_{t-1}$$

Applied independently to each coordinate: $x$, $y$, $\text{width}$, $\text{height}$.

| Symbol | Description | Value |
|---|---|---|
| $\hat{b}_t$ | Smoothed box coordinate at frame $t$ | output |
| $b_t$ | Raw detected box coordinate at frame $t$ | Vision output |
| $\hat{b}_{t-1}$ | Smoothed box coordinate at frame $t-1$ | previous state |
| $\alpha$ | Smoothing factor | 0.25 |

Lower $\alpha$ → more temporal smoothing, slower response to movement. $\alpha = 0.25$ was chosen to eliminate flicker while remaining responsive to a walking pedestrian.

---

### 5. Traffic Light Classification — HSV Colour Space
*`Services/TrafficLightColorClassifier.swift`*

**BGRA → HSV conversion:**

Let $r, g, b \in [0, 1]$, $C_{\max} = \max(r,g,b)$, $\delta = C_{\max} - \min(r,g,b)$.

$$V = C_{\max} \qquad S = \frac{\delta}{C_{\max}} \qquad H = \begin{cases} 60°\times\dfrac{g - b}{\delta} \bmod 360° & C_{\max} = r \\[6pt] 60°\times\left(\dfrac{b - r}{\delta} + 2\right) & C_{\max} = g \\[6pt] 60°\times\left(\dfrac{r - g}{\delta} + 4\right) & C_{\max} = b \end{cases}$$

**Pixel acceptance filter:** $V > 0.20$ AND $S > 0.20$ (bright, saturated pixels only — filters out dark background).

**Hue acceptance windows:**

| Colour | Hue range |
|---|---|
| Red | $H \in [0°, 25°] \cup [335°, 360°]$ |
| Yellow | $H \in [20°, 70°]$ |
| Green | $H \in [80°, 170°]$ |

**Score per region:**

$$\text{score} = \frac{\text{matching pixels sampled}}{\text{total pixels sampled}}$$

Every 3rd pixel is sampled for performance. The bbox is split into three vertical regions: top 30 % (red), middle 30 % (yellow), bottom 30 % (green). The region with the highest score above **threshold = 0.06** determines the detected colour.

---

### 6. Crosswalk Box Merging — Union Hull
*`Services/ObjectTracker.swift`*

$$\text{mergedBox} = \Bigl(\min_i x_i^{\min},\;\; \min_i y_i^{\min},\;\; \max_i x_i^{\max} - \min_i x_i^{\min},\;\; \max_i y_i^{\max} - \min_i y_i^{\min}\Bigr)$$

Where $x_i^{\min}, y_i^{\min}, x_i^{\max}, y_i^{\max}$ are the edges of the $i$-th crosswalk bounding box.

The merged track inherits all properties (confidence, distanceMeters, walkSignalRecommendation) from the **highest-confidence** individual detection. All other stripe tracks are discarded.

---

### 7. Vision Coordinate Flip
*`Services/WalkSignalTimerService.swift`, `Services/TrafficLightColorClassifier.swift`*

Vision framework uses a **bottom-left** origin; UIKit and Core Image use a **top-left** origin. The flip is applied before any pixel-level crop:

$$y_{\text{flipped}} = 1.0 - y_{\text{maxVision}}$$

$$\text{flippedBox} = \bigl(x_{\min},\;\; 1.0 - y_{\max},\;\; w,\;\; h\bigr)$$

For `cropPixelBuffer`, after converting to pixel coordinates the CIImage Y coordinate is additionally flipped:

$$y_{\text{CI}} = H_{\text{buffer}} - y_{\text{maxPixel}}$$

---

### 8. Walk Signal Asymmetric Crop Expansion
*`Services/WalkSignalTimerService.swift`*

US pedestrian signals have the **countdown number panel immediately to the right** of the figure panel that YOLO detects. The crop is deliberately asymmetric to capture it:

$$x' = \max\!\bigl(0,\; x - 0.10 \cdot w\bigr)$$

$$y' = \max\!\bigl(0,\; y - 0.15 \cdot h\bigr)$$

$$w' = \min\!\bigl(1 - x',\; w \times 1.90\bigr) \qquad \text{(+10\% left, +80\% right)}$$

$$h' = \min\!\bigl(1 - y',\; h \times 1.30\bigr) \qquad \text{(+15\% top and bottom)}$$

All values are normalised (0 – 1) and clamped to frame bounds. After expansion the region is converted to pixel coordinates and passed to `VNRecognizeTextRequest` (`.fast` mode, `minimumTextHeight = 0.08`).

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
