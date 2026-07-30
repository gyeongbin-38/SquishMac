# MacBook Test Checklist

Use an Apple Silicon MacBook with a built-in Force Touch trackpad and macOS 13 or later. Record the Mac model and macOS version with every result.

## 1. Build Gate

```sh
git pull
swift test
bash Scripts/package-app.sh
open .build/SquishMac.app
```

Confirm that all tests pass, `SquishMac.app` launches, the icon appears in the menu bar, and no Dock icon remains after launch.

## 2. Basic App Flow

- Turn SquishMac off and confirm that gestures do not play sound.
- Turn it on and confirm that `Test Sound` plays at the configured master volume.
- Open Settings and confirm that mode, response, density, volume, and motion options survive an app restart.
- Confirm that `Played Today` increments only after audible playback and resets correctly.

## 3. Trackpad Detection

- Open `Open Squish Surface...` and click or touch inside the surface.
- Confirm that touch points follow the physical fingers without swapping during crossing movements.
- Confirm that `Fingers` reaches the expected count, especially 6 in Slime mode.
- Hold exactly two fingers on the surface, vary Force Touch pressure without moving, and confirm `Fingers` remains at 2.
- Lift one of two fingers while pressure remains and confirm the surviving finger stays visible.
- Press firmly and confirm the status changes to `Force pressure detected`.
- Confirm that pressure rises and falls smoothly and Force Touch stage changes are visible.
- Move one finger while holding the others still and confirm movement remains stable.
- With gesture protection enabled, perform three- and four-finger horizontal/vertical swipes inside the surface.
- If macOS still opens Mission Control or changes Spaces, disable those gestures in `System Settings > Trackpad > More Gestures` and record the macOS version.

## 4. Six-Finger Slime

- Place three to six fingers down gradually; confirm knead sounds begin without a burst of repeated sounds.
- Move four or more fingers across the pad; confirm stretch sounds differ from knead sounds.
- Select `Doctor Putty (Pastel Pink)`, move four to six fingers slowly, and confirm normal stretch sounds.
- With Doctor Putty still selected, exceed movement `0.72`; confirm one failure snap plays and does not repeat until movement falls below `0.38`.
- Select another slime and repeat the fast movement; confirm it remains a normal stretch without the Doctor Putty snap.
- Select `White Dense Putty (Video 5)` and confirm compact presses use its knead pack while four-or-more-finger pulls above movement `0.20` use its short-pull pack.
- Confirm Video 5 plays more quietly and less densely than a standard slime profile, and never shows `Bar-pung ready`.
- Confirm quick knead-to-stretch changes do not chatter, generic pop layers do not appear, and consecutive sounds remain at least about 0.38 seconds apart.
- Select `Aerated Clear Slime (Video 6)` and confirm a two-finger pressure poke uses its bubbly knead pack.
- With Video 6 selected, use four or more fingers above movement `0.14`; confirm the broad-pull pack plays and `Bar-pung ready` never appears.
- Confirm Video 6 sounds remain material-only at 72% profile gain and are spaced by at least about 0.24 seconds.
- Select `Dense White Clay Slime (Video 7)` and confirm two opposing pressure contacts use its dense press/knead pack.
- With Video 7 selected, use four or more contacts above movement `0.16`; confirm the short-pull/fold pack plays.
- Confirm Video 7 sounds remain material-only at 66% profile gain, are spaced by at least about 0.32 seconds, and never show `Bar-pung ready`.
- Select `Pink Gummy Jelly Slime (Video 8)` and confirm two pressure contacts use its pinch/pop/knead pack.
- With Video 8 selected, use four or more contacts above movement `0.14`; confirm the pull/fold pack plays.
- Confirm Video 8 sounds remain material-only at 68% profile gain, are spaced by at least about 0.30 seconds, and never show `Bar-pung ready`.
- Select `White Poke Putty (Video 9)` and confirm two-contact deep presses use quiet body friction while firmer presses sometimes add a clay snap or suction detail.
- With Video 9 selected, use four or more contacts above movement `0.18`; confirm the texture pool becomes primary, total gain remains controlled near 66%, and events stay about 0.28 seconds apart.
- Select `Orange Glossy Slime (Video 10)` and confirm two-contact pokes use micro-pops; increase pressure and confirm firm snaps appear occasionally rather than on every press.
- Confirm Video 10 remains controlled near 64% profile gain and events stay about 0.26 seconds apart.
- Select `Green Micro-Bead Floam (Video 11)` and confirm precise two-contact presses use body friction plus pressure-dependent bead details.
- With Video 11 selected, use four or more contacts above movement `0.16`; confirm bead pops become primary and events stay about 0.24 seconds apart.
- Select `Clear Slime (Video 3)` and confirm knead/press and stretch gestures use audibly different source pools.
- Confirm Video 3 sounds are slightly quieter than the same master-volume setting on a standard profile.
- With Video 3 selected, spread five or six fingers beyond `0.60`; confirm `Bar-pung ready` appears.
- Within 1.25 seconds, reduce spread by at least `0.16` while movement exceeds `0.10` and pressure exceeds `0.30`; confirm one bar-pung event plays.
- Repeat the closing movement without a new wide preparation; confirm bar-pung does not repeat.
- Confirm the profile-adjusted values show approximately `0.96x` response and `1.08x` sound density before user multipliers.
- Hold all fingers still; confirm sound does not repeat continuously without movement or pressure change.
- Lift only one or two fingers; confirm the release sound does not fire.
- Lift the final fingers; confirm exactly one release sound fires.
- Repeat at response values `0.5x`, `1.0x`, and `1.75x` and note the most natural value.

## 5. Two-Thumb Wax Crush

- Select `Pastel Wax Shell Slime (Video 4)` and confirm the profile-adjusted values show approximately `1.08x` response and `1.18x` sound density before user multipliers.
- Confirm two contacts remain visible in the live finger counter while Force Touch pressure changes.
- Place two thumbs lightly; confirm a press sound occurs.
- Increase pressure past roughly `0.43`; confirm a restored Video 4 crack plays.
- Add distinct squeeze pulses without releasing; confirm fresh micro-cracks can play but a motionless hold stays quiet.
- Continue past roughly `0.74`; confirm the final Video 4 crush plays once.
- Confirm the optional haptic produces one level change at crack and one stronger response at crush.
- Hold the firm press without changing pressure or contact distance; confirm crack and crush do not loop.
- Fully release and press again; confirm a new press/crack/crush cycle is allowed.
- Test slow pressure ramps and quick pressure jumps separately.

## 6. Audio Quality

- Perform at least 30 gestures in each mode and confirm there are no immediate duplicate files.
- Confirm stronger gestures are louder and use a different playback rate without clipping.
- Move master volume to zero and confirm no sound is counted.
- Temporarily remove or corrupt a test sound in a local branch and confirm Settings displays a playback error rather than a system beep.
- Listen with speakers and headphones for clicks at sample boundaries and excessive overlap.

## 7. Recording Export

- Start recording, perform both gentle and strong gestures, then stop and export JSON.
- Confirm the file contains `schema_version`, `samples`, `events`, and `tuning`.
- Confirm sample relative times increase, coordinates remain between 0 and 1, and event kinds match audible gestures.
- Change mode during a recording and confirm each sample keeps the correct mode.
- Leave a long recording active and confirm it stops at 36,000 samples without crashing.

## 8. Optional Motion Input

- Enable `Motion impact sounds`; note the reported motion source and detector state.
- Recalibrate on a stable desk, then lightly tap the chassis away from the display and trackpad.
- Confirm sensitivity and cooldown changes alter triggering as expected.
- Disable motion input and confirm normal trackpad interaction continues.

Do not repeatedly hit the display, hinge, or enclosure. The impact feature should be tested with light taps only.

## 9. Camera Slime

- Open `Open Camera Slime...` and grant camera permission.
- Select `Clear Slime (Video 3)` and confirm the camera readout shows a stretch threshold near `21%`.
- Confirm the preview starts and up to ten fingertip points follow two visible hands.
- Confirm no frames, landmarks, or recordings are written to disk without an explicit export.
- Test Slime with three to ten visible fingertips and confirm press, knead, stretch, and release sounds.
- Select `White Dense Putty (Video 5)` and confirm compact movement near `0.20` remains a knead while broad movement above `0.32` becomes a short pull.
- Select `Aerated Clear Slime (Video 6)` and confirm compact motion near `0.10` remains a bubble poke/knead while movement above `0.224` with spread above `0.263` becomes a membrane pull.
- Confirm Video 6 never enters `Bar-pung ready`, even with two open hands.
- Select `Dense White Clay Slime (Video 7)` and confirm compact motion above `0.10` remains a press/knead while movement above `0.30` with spread above `0.48` becomes a short pull/fold.
- Confirm Video 7 accepts a compact two-fingertip press, suppresses another sound inside about 0.32 seconds, and never enters `Bar-pung ready`.
- Select `Pink Gummy Jelly Slime (Video 8)` and confirm compact motion above `0.073` remains a pinch/knead while movement above `0.191` with spread above `0.307` becomes a jelly pull.
- Confirm Video 8 accepts a compact two-fingertip pinch, suppresses another sound inside about 0.30 seconds, and never enters `Bar-pung ready`.
- Select Video 9 and confirm a two-fingertip compact press is accepted near pressure estimate `0.46`, while a pull needs movement near `0.32` and spread near `0.42`.
- Select Video 10 and confirm compact pokes begin near movement `0.062`; a pull needs movement near `0.204` and spread near `0.370`.
- Select Video 11 and confirm precise two-fingertip presses work for the small material; a pull needs movement near `0.310` and spread near `0.346`.
- For Videos 9-11, confirm stronger estimated pressure increases texture detail without clipping, abrupt jumps, generic impact sounds, or more than two simultaneous material layers.
- With Video 3 selected, show two open hands with at least eight tracked fingertips and broad spread; confirm `Bar-pung ready` appears.
- Within 1.4 seconds, move both hands downward quickly while keeping them broadly separated; confirm one camera bar-pung event plays.
- Repeat with one hand or with mostly inward movement and confirm camera bar-pung does not trigger.
- Switch to Wax, select `Pastel Wax Shell Slime (Video 4)`, and confirm the readout shows crack near `43%` and crush near `74%`.
- Bring two visible fingertips together while increasing hand compression; confirm press, repeated fine-crack, and crush stages use the Video 4 packs and reset after release.
- Cover the camera and confirm tracking clears without repeated sounds or a crash.
- Deny camera permission once and confirm the window gives a recoverable Privacy & Security message.

## 10. Reference Video

- Analyze one owned Slime video and one owned Wax video, each with an audio track.
- Confirm progress reaches 100% and exported JSON decodes successfully.
- Spot-check fingertip positions, gesture timestamps, and linked audio event indices.
- Analyze a valid silent video and confirm it succeeds with an empty `audio_events` array.
- Cancel or close a long analysis and confirm the app remains responsive.

## Result Template

```text
Mac model:
macOS version:
Build commit:
Maximum reported fingers:
Pressure events detected: yes/no
Stage 2 detected: yes/no
Best slime response/density:
Best wax response/density:
Audio issues:
JSON export issues:
Two-finger retention:
System gesture result:
Camera tracking result:
Reference video result:
Other notes:
```
