# SquishMac

SquishMac is a Swift macOS menu bar sound toy built around a Force Touch trackpad. Its primary surface turns multi-touch movement and pressure into slime kneads, stretches, releases, wax presses, cracks, and crushes. The project is original and does not reuse another app's code, branding, or sound assets.

## Current Features

- Menu bar-only launch with a global On/Off switch.
- `6-Finger Slime` and `2-Thumb Wax Crush` interaction modes.
- Stable per-touch identity tracking for finger count, normalized position, movement, and spread.
- Force Touch pressure and stage tracking through AppKit pressure events.
- Pressure events retain the last active touch set, preventing two-finger input from disappearing between touch updates.
- Best-effort in-app suppression of scroll, swipe, magnify, rotate, and smart-magnify gestures while the Squish Surface is active.
- Optional one-shot haptic feedback for wax crack and crush stages.
- Stateful wax progression so press, crack, and crush do not repeat while a press is held.
- Pressure-sensitive volume and playback rate, master volume, touch response, and sound density controls.
- Shuffle-bag sound selection that plays every variation before repeating and avoids consecutive duplicates.
- Lazy in-memory audio caching for lower response latency.
- Layered sound recipes that probabilistically combine wet contact, bubbles, suction, creaks, cracks, and crush debris.
- Versioned JSON recording of trackpad samples and recognized gesture events.
- Local reference-video analysis with Vision fingertip tracking, audio-onset detection, gesture/audio alignment, and learned tuning suggestions.
- Separate material profiles and dataset directories for clear, glossy, butter, cloud, jelly, icee, floam, crunchy, and wax-shell slime.
- Live camera slime and wax interaction with on-device two-hand tracking and a virtual material overlay.
- Optional MacBook impact detection, sensitivity, cooldown, custom sound folders, launch at login, and a daily play counter.
- Generated placeholder WAV files for Bubble, Slime, Squishy, Pop, and Wax packs.

## Trackpad Input Model

Open `Open Squish Surface...` from the menu bar. The window must be active because public AppKit touch events are delivered to the active responder surface.

AppKit exposes touch identity and normalized touch position separately from the pressure event stream. SquishMac therefore combines:

- touch count, identity, position, movement, and spread from `NSTouch`;
- normalized pressure and Force Touch stage from `NSEvent`;
- a stateful gesture model that applies response and sound-density tuning.

This is aggregate interaction pressure, not an independent pressure value for every finger. Real Force Touch hardware testing is required to tune how pressure events line up with six simultaneous touches and two-thumb input.

The in-app gesture guard can consume gestures delivered to the Squish Surface. macOS may recognize Mission Control or desktop switching before an app receives those events, so disable the relevant options in `System Settings > Trackpad > More Gestures` during full-surface testing if Spaces still changes.

## Build and Run

Requirements: an Apple Silicon MacBook, macOS 13 or later, and Xcode command-line tools.

```sh
swift test
swift run SquishMac
```

To produce a menu bar-only app bundle:

```sh
bash Scripts/package-app.sh
open .build/SquishMac.app
```

`Info.plist` has `LSUIElement=true`, so the packaged app does not show a Dock icon.

## Recording Sessions

The Squish Surface can record up to 36,000 input samples and export a JSON file. Each sample contains relative time, mode, finger count, pressure, Force Touch stage, movement, spread, intensity, and normalized touch coordinates. Recognized sound gestures are stored as a separate event list.

These files are intended for hardware calibration and later comparison with owned or licensed reference videos. See [Trackpad recording format](Docs/TRACKPAD_RECORDING_FORMAT.md).

## Reference Video and Camera

`Analyze Reference Video...` reads a local movie at 15 analyzed frames per second. It records wrist and fingertip landmarks for up to two hands, derives movement/spread/pinch/pressure estimates, detects audio onsets, aligns inferred gestures with nearby audio events, and exports the complete timeline as JSON. The current profile builder is data-derived threshold tuning, not a trained neural network. See [Reference analysis workflow](Docs/REFERENCE_ANALYSIS.md).

Choose or create a material profile before analysis. Completed analyses are automatically stored under `Application Support/SquishMac/ReferenceDatasets/<material-profile>/<dataset-id>/analysis.json`, keeping tuning and sound mappings separate for each slime.

`Open Camera Slime...` uses the built-in camera and Apple's on-device Vision hand-pose request. Camera frames are not uploaded or saved by SquishMac. The camera pressure value is a visual estimate derived from hand compression and pinch, not physical Force Touch pressure.

To inspect a completed analysis on Windows, start the local browser preview:

```powershell
python Tools/reference_preview_server.py --dataset AnalysisOutput/1
```

The preview synchronizes the tracked video with per-frame hand, fingertip,
movement, relative-pressure, gesture, and extracted-audio data. It can also
auto-play mapped clips while the tracked video is playing. `AnalysisOutput/`
remains ignored by Git so private footage and extracted audio are not pushed.

## Sound Packs

Add `.wav`, `.mp3`, `.m4a`, `.aiff`, or `.aif` files to:

```text
Sources/SquishMac/Resources/Sounds/bubble
Sources/SquishMac/Resources/Sounds/slime
Sources/SquishMac/Resources/Sounds/squishy
Sources/SquishMac/Resources/Sounds/pop
Sources/SquishMac/Resources/Sounds/wax
```

The included sounds are generated development placeholders. Replace them with original or properly licensed recordings before release. A custom folder can also be selected from Settings for impact sounds.

## Project Layout

```text
Sources/SquishMac/
  AppDelegate.swift                 menu bar, windows, and app flow
  MotionDetector.swift              optional MacBook accelerometer input
  SoundPlayer.swift                 variation, response curve, cache, playback
  SoundPackManager.swift            bundled and custom sound discovery
  SettingsStore.swift               persisted settings and daily counter
  SettingsView.swift                general settings UI
  TrackpadGestureEngine.swift       slime and wax state machines
  TrackpadInteractionState.swift    live diagnostics and recording state
  TrackpadLabView.swift             AppKit touch surface and SwiftUI controls
  TrackpadSessionRecorder.swift     versioned JSON session export
  TrackpadTouchMetrics.swift        identity-based movement and spread
  CameraSlimeController.swift       camera capture and live Vision tracking
  CameraSlimeView.swift             camera preview and virtual material overlay
  ReferenceVideoAnalyzer.swift      offline motion/audio timeline analysis
  HandMotionAnalyzer.swift          hand features and gesture inference
  GestureSoundRecipeLibrary.swift   probabilistic multi-layer sound mappings
  SlimeMaterialProfile.swift        material taxonomy and profile metadata
  ReferenceDatasetLibrary.swift     profile-separated local dataset storage
Tools/
  reference_video_analysis.py       offline MediaPipe motion/audio extraction
```

## Validation and Distribution

GitHub Actions builds the Swift package, runs unit tests, packages `SquishMac.app`, checks all bundled sound-pack directories, and uploads the app artifact. Tags matching `v*` create an unsigned release zip.

The remaining validation requires a physical Force Touch MacBook and an owned reference video. Follow [the MacBook test checklist](Docs/MACBOOK_TEST_CHECKLIST.md). Code signing, notarization, final branding, production sounds, and final video-derived tuning remain release work.

The optional impact detector dynamically reads IOHID accelerometer events because Core Motion does not provide the same macOS API. That path can vary by hardware or macOS release and is not suitable for Mac App Store assumptions; the primary trackpad path uses public AppKit APIs.
