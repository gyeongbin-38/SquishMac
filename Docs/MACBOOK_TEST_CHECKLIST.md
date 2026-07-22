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
- Press firmly and confirm the status changes to `Force pressure detected`.
- Confirm that pressure rises and falls smoothly and Force Touch stage changes are visible.
- Move one finger while holding the others still and confirm movement remains stable.

## 4. Six-Finger Slime

- Place three to six fingers down gradually; confirm knead sounds begin without a burst of repeated sounds.
- Move four or more fingers across the pad; confirm stretch sounds differ from knead sounds.
- Hold all fingers still; confirm sound does not repeat continuously without movement or pressure change.
- Lift only one or two fingers; confirm the release sound does not fire.
- Lift the final fingers; confirm exactly one release sound fires.
- Repeat at response values `0.5x`, `1.0x`, and `1.75x` and note the most natural value.

## 5. Two-Thumb Wax Crush

- Place two thumbs lightly; confirm a press sound occurs.
- Increase pressure; confirm a crack occurs once.
- Continue to a firm press; confirm a crush occurs once.
- Confirm the optional haptic produces one level change at crack and one stronger response at crush.
- Hold the firm press; confirm crack and crush do not loop.
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
Other notes:
```
