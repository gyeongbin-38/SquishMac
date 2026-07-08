# SquishMac

SquishMac is a Swift-based macOS menu bar app MVP. It detects a quick hit or shake on supported MacBook motion sensors, chooses a random squishy sound from the selected pack, and scales playback volume from the detected impact strength.

## Run in VS Code

```sh
swift run SquishMac
```

The app starts as a menu bar utility and hides from the Dock with `NSApp.setActivationPolicy(.accessory)`.

## Build an app bundle

```sh
bash Scripts/package-app.sh
open .build/SquishMac.app
```

The bundle uses `Info.plist` with `LSUIElement=true`, so it launches as a menu bar app only.

## Sound packs

Put additional `.wav`, `.mp3`, `.m4a`, `.aiff`, or `.aif` files in:

```text
Sources/SquishMac/Resources/Sounds/bubble
Sources/SquishMac/Resources/Sounds/slime
Sources/SquishMac/Resources/Sounds/squishy
Sources/SquishMac/Resources/Sounds/pop
```

The included sounds are generated placeholders for the MVP, not copied from any existing app.

## Motion sensor note

The detector tries CoreMotion first, then an IOHIDEventSystem fallback. Actual impact detection must be tested on a supported Apple Silicon MacBook because macOS sensor exposure differs by hardware and OS version.
