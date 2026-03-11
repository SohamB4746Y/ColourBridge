# Changelog

All notable changes to **ColourBridge** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/) and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.4.0] — 2026-03-11

### Phase 5 — Documentation & Final Polish

#### Added
- `CHANGELOG.md` tracking all refactoring phases.

#### Changed
- Updated `README.md` to reflect new architecture (`AppConstants`, `Components`, shared `CIContext`).
- Documented haptic feedback, CVD-safe chart colours, animated chart entrance, sample list, and Settings deep-link.
- Checked off haptic feedback in the Future Enhancements roadmap.
- Added `AppConstants.swift` and `Components.swift` to the project structure table.
- Expanded Architecture, Accessibility, and Performance sections with new details.

---

## [1.3.0] — 2026-03-11

### Phase 4 — UI/UX Polish & Animations

#### Added
- Spring scale-in animation on `TapIndicatorView` with asymmetric insertion/removal transitions.
- Soft shadow on `AnalysisInfoCard` for depth.
- Spring-animated content transition on `AnalysisInfoCard` keyed to `currentSample.id`.
- Staggered button entry animation on the WelcomeView welcome screen.
- Gradient border overlay on preview cards in `ContentView`.
- Animated bar chart entrance in `SummaryView` (bars grow in with a delayed ease-out).
- Sample list section in `SummaryView` showing colour swatches, hex codes, and readability badges (AAA / AA / Low).
- "Open Settings" deep-link button on the camera-denied screen in `CameraAnalyzeView`.
- Haptic feedback on the "Restart Demo" button in `SummaryView`.

---

## [1.2.0] — 2026-03-11

### Phase 3 — Accessibility Enhancements

#### Added
- `HapticEngine` in `Components.swift` — light impact for sample taps, medium for navigation, notification for results.
- Haptic calls (`sampleTap`, `action`) on camera/photo tap and summary button interactions.
- `accessibilityHint` on the simulation mode picker and "See Summary" button in `AnalysisInfoCard`.
- `accessibilityLabel` and `accessibilityHidden` on decorative icons across all views.
- `accessibilitySortPriority(1)` on `AnalysisInfoCard` to surface it first for VoiceOver.
- CVD-safe blue/orange palette for the `SummaryView` bar chart (replaces default green/red).
- `accessibilityAddTraits(.isHeader)` on section headings in `SummaryView`.
- `accessibilityElement(children: .combine)` on explanation text blocks.
- `accessibilityElement(children: .contain)` and chart-level labels on the bar chart.

---

## [1.1.0] — 2026-03-11

### Phase 2 — Performance & Memory Optimisation

#### Changed
- Introduced `ColorAnalyzer.sharedContext` — a single `CIContext` reused across all Core Image operations, eliminating per-frame allocations.
- Camera display image is now cached (`cachedDisplayImage`) and rebuilt only when the frame or simulation mode changes via `onChange`, replacing redundant per-render CIContext work.
- Same cached-display-image pattern applied to `SampleAnalyzeView`.
- Added `deinit` to `CameraManager` to ensure `AVCaptureSession.stopRunning()` is called when the manager is deallocated.
- Replaced `DispatchQueue.main.asyncAfter` with `Task.sleep(for:)` for tap-indicator dismissal (structured concurrency).
- Instruction banner extracted into a shared `instructionBanner` computed property.

---

## [1.0.0] — 2026-03-11

### Phase 1 — Architecture Cleanup

#### Added
- `AppConstants.swift` — centralised enum containing every magic number (analysis thresholds, layout metrics, chart rendering params, CVD matrices).
- `Components.swift` — reusable `ColorSwatchView`, `TapIndicatorView`, and `AnalysisInfoCard` shared by camera and sample analysis screens.
- `MARK` section separators throughout every Swift file for Xcode jump bar navigation.
- `SimulationMode.matrixVectors` computed property to encapsulate CVD matrix lookup.
- `ColorSample.hexString` computed property for display-ready hex formatting.

#### Changed
- Replaced all scattered magic numbers with `AppConstants` references.
- Extracted duplicated UI code (swatch, tap ring, info card) into reusable components.
- Applied production-quality doc comments on every public type, property, and method.
