# Reference Video Analysis

SquishMac can turn an owned or licensed slime or wax video into a timestamped local analysis. This is the bridge between filmed material behavior and the trackpad/camera sound engine.

## What Is Measured

The analyzer samples video at 15 frames per second and uses Apple's Vision hand-pose request for up to two hands. Every accepted frame stores:

- wrist plus thumb, index, middle, ring, and little fingertip coordinates;
- visible hand and fingertip counts;
- identity-based fingertip movement;
- fingertip spread and average hand openness;
- thumb/index pinch and a normalized pressure estimate.

The audio track is decoded to mono PCM. Adaptive onset detection records RMS, peak amplitude, zero-crossing rate, crest factor, a raw acoustic texture, a material-aware suggested texture, and a suggested clip range. For example, the same sharp transient can remain `brittle_crack` for wax while becoming `clay_snap` for butter/clay slime. Gesture events are inferred from motion features, then linked to the closest audio event.

## App Workflow

1. Open `Analyze Reference Video...` from the menu bar.
2. Select an existing material profile or create a separate profile for the physical slime.
3. Choose a local `.mov`, `.mp4`, or other macOS-readable movie.
4. Wait for motion and audio analysis to complete.
5. Export the JSON result.

The JSON contains `motion_frames`, `audio_events`, `gesture_events`, `learned_profile`, and `sound_recipes`. `audio_event_index` links a gesture to the audio event that most likely belongs to it.

Each profile is stored separately under:

```text
~/Library/Application Support/SquishMac/ReferenceDatasets/
  <material-profile-id>/
    <dataset-id>/
      analysis.json
```

Built-in categories include clear, thick and glossy, butter/clay, cloud, jelly, icee, floam/bead, crunchy, and wax-shell slime. Custom profiles allow two slimes in the same category to retain different tuning and sound behavior.

Specific products can refine a broad category with profile-only interaction
rules. The Doctor Putty profile remains in the butter/clay category but defines
a fast-stretch failure threshold, its own failure sound pack, and controlled
stretch guidance. Those rules do not affect other butter/clay slimes.

For command-line or collaborative analysis, place local footage under `ReferenceVideos/` and exported data under `AnalysisOutput/`. Both directories are ignored by Git so personal footage is not pushed to the public repository.

## Detailed Offline Extraction

The companion Python tool produces all 21 landmarks per hand, a tracked preview video, calibrated motion features, onset-aligned sound events, and individual WAV clips:

```powershell
py -3.12 -m venv .venv-analysis
.\.venv-analysis\Scripts\python.exe -m pip install -r Tools\requirements-analysis.txt
.\.venv-analysis\Scripts\python.exe Tools\reference_video_analysis.py `
  --video "ReferenceVideos\sample.mp4" `
  --output "AnalysisOutput\sample" `
  --material-id "wax-shell-sample" `
  --material-name "Wax Shell Sample" `
  --material-category "wax_shell_slime"
```

Output is separated into `motion/landmarks.json`, `events/gesture_timeline.json`, `audio/events.json`, `audio/clips/<gesture>/`, `overlays/tracking.mp4`, and `overlays/poster.jpg`. Frames with no detected hands remain in the motion timeline as quality evidence but are excluded from inferred gestures, preventing motion blur or an out-of-frame hand from becoming a false release event.

## Recording Recommendations

- Use a fixed camera, stable lighting, and a background that contrasts with the hands.
- Keep fingertips visible and avoid motion blur.
- Record at 60 fps when possible; SquishMac currently analyzes a stable 15 fps subset.
- Capture clean audio without music, speech, automatic noise suppression, or clipping.
- Include several slow, medium, and fast repetitions of each action.
- Film slime press, knead, stretch, and release separately before mixed sequences.
- Film wax press, first crack, and full crush separately.
- Use a visible clap or tap at the beginning when comparing a video with a trackpad recording.

## Sound Expansion

The video provides timing and real reference texture. SquishMac also exports semantic recipes for layers that may be absent from one recording:

```text
slime: wet contact + dense fold + micro bubbles + suction
wax: soft compression + surface creak + brittle crack + body crush + debris
```

At runtime, the primary gesture sound always plays. Secondary layers use controlled probability, intensity-dependent volume, playback-rate variation, and short randomized delay. This widens repetition without claiming that an invented layer came from the source video.

## Current Boundary

The included analyzer learns percentile-based response and sound-density suggestions. It does not retrain Apple's Vision model or create a generative audio model. Once real footage is available, the exported features can be used to tune gesture thresholds, split original audio clips, and train a separate sequence model if the amount and licensing of data justify it.

Reference media and extracted audio must be original, public-domain, or licensed for the intended use.
