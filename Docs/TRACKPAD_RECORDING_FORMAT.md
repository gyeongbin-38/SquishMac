# Trackpad Recording Format

SquishMac exports UTF-8 JSON with `schema_version: 2`. Property names use snake case and dates use ISO 8601.

## Top-Level Fields

| Field | Meaning |
| --- | --- |
| `schema_version` | Format version for future migrations |
| `app_version` | App bundle version or `development` |
| `os_version` | macOS version reported by the process |
| `architecture` | Usually `arm64` on supported MacBooks |
| `started_at`, `ended_at` | Session wall-clock bounds |
| `tuning` | Response and sound density active at recording start |
| `material_profile_id` | Selected slime profile, or `null` for non-slime sessions |
| `samples` | Ordered raw and derived trackpad observations |
| `events` | Ordered recognized slime and wax gestures |

## Sample Fields

| Field | Range or values |
| --- | --- |
| `relative_time` | Seconds from session start |
| `mode` | `sixFingerSlime` or `twoThumbWaxCrush` |
| `finger_count` | Number of active indirect touches |
| `pressure` | Normalized aggregate event pressure, `0...1` |
| `force_stage` | AppKit pressure stage, normally `0...2` |
| `movement` | Identity-matched average movement, normalized to `0...1` |
| `spread` | Farthest distance between touches, normalized to `0...1` |
| `intensity` | Gesture engine output, `0...1` |
| `touches` | Touch identity plus normalized `x` and `y` coordinates |

Touch identities are only meaningful inside one touch lifetime and one session. They should not be treated as persistent finger or user identifiers.

## Event Fields

Each event contains `relative_time`, `kind`, and normalized `intensity`. Current kinds are:

```text
slimeKnead
slimeStretch
slimeStretchFailure
slimeRelease
waxPress
waxCrack
waxCrush
```

`slimeStretchFailure` is emitted only when the selected material profile defines
a fast-stretch failure threshold. For example, Doctor Putty uses this event for
the snap produced when the material is pulled too quickly.

## Reference Video Alignment

The built-in reference analyzer can produce a separate timeline from an owned or licensed video. Use a visible or audible sync action at the beginning of both recordings when comparing the two:

```text
reference video + audio
          |
          v
hand landmarks and audio onsets
          |
          v
timestamped reference gesture events
          |
          v
compare with SquishMac samples/events
          |
          v
updated thresholds, response curves, and layered sound mappings
```

See [Reference video analysis](REFERENCE_ANALYSIS.md) for its export fields and recording guidance.

Reference media and extracted audio must be original, public-domain, or licensed for the intended use.
