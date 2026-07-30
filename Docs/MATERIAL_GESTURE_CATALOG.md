# Material and Gesture Catalog

This catalog keeps every reference material independent. A gesture or sound
learned from one video is never silently reused by another material profile.
Source videos and local analysis artifacts remain ignored by Git.

## Interpretation

- Camera pressure is a relative estimate derived from hand compression, pinch,
  spread, and movement. It is not physical Force Touch pressure.
- Trackpad pressure is aggregate Force Touch pressure. macOS does not expose an
  independent pressure value for each finger.
- Camera thresholds come from the analyzed video percentiles and frame review.
- Trackpad thresholds are material priors until a physical MacBook session is
  recorded.
- A primary sound always comes from the selected material. Optional secondary
  layers also come from that same material and remain below the primary volume.

## Reference Index

| Video | Runtime profile | Classification | Characteristic gesture | Runtime sound result |
| --- | --- | --- | --- | --- |
| 1 | Dark Brown Wax Shell / Yellow Slime Core | Wax shell | Two-thumb shell crush, then core handling | Generic wax path pending a clean profile-only split |
| 2 | Doctor Putty (Pastel Pink) | Butter / clay | Controlled pull; excessive pull speed breaks the putty | Two profile-only failure snaps |
| 3 | Clear Slime | Clear | Press, broad stretch, downward bar-pung seal | 34 knead/press + 6 stretch clips |
| 4 | Pastel Wax Shell Slime | Wax shell | Opposing-contact press, progressive cracks, full crush | 18 press + 5 crack + 1 crush clips |
| 5 | White Dense Putty | Butter / clay | Compact pinch, firm press, short controlled pull | 14 knead/press + 6 pull clips |
| 6 | Aerated Clear Slime | Clear | Bubble poke, fold, broad membrane pull | 35 knead/press + 7 pull clips |
| 7 | Dense White Clay Slime | Butter / clay | Deep opposing press, short pull, rounded fold | 20 knead/press + 9 pull/release clips |
| 8 | Pink Gummy Jelly Slime | Jelly | Sticky pinch/pop, long or short pull, twist, fold | 24 knead/pop + 6 pull/release clips |
| 9 | White Poke Putty | Butter / clay | Deep fingertip poke, broad press, short fold and pull | 13 body + 17 clay snap/suction clips |
| 10 | Orange Glossy Slime | Thick and glossy | Two-hand fold/squeeze, repeated 2-4 fingertip pokes | 7 micro-pop + 2 firm snap clips |
| 11 | Green Micro-Bead Floam | Floam / bead | Precise thumb-index pinch and compact press | 6 body-friction + 16 bead pop/snap clips |

## Runtime Rules

| Video | Min contacts | Trackpad pull movement | Camera knead / pull movement | Camera spread | Camera press | Gain | Min interval |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 3 | 3 | 0.14 | 0.075 / 0.210 | 0.300 | 0.320 | 0.86 | engine default |
| 4 | 2 | wax stages | 0.097 / 0.243 | 0.399 | 0.180 | 0.92 | wax stage cooldowns |
| 5 | 3 | 0.20 | 0.120 / 0.320 | 0.410 | 0.388 | 0.68 | 0.38 s |
| 6 | 2 | 0.14 | 0.063 / 0.224 | 0.263 | 0.350 | 0.72 | 0.24 s |
| 7 | 2 | 0.16 | 0.100 / 0.300 | 0.480 | 0.300 | 0.66 | 0.32 s |
| 8 | 2 | 0.14 | 0.073 / 0.191 | 0.307 | 0.372 | 0.68 | 0.30 s |
| 9 | 2 | 0.18 | 0.120 / 0.320 | 0.420 | 0.460 | 0.66 | 0.28 s |
| 10 | 2 | 0.16 | 0.062 / 0.204 | 0.370 | 0.260 | 0.64 | 0.26 s |
| 11 | 2 | 0.16 | 0.120 / 0.310 | 0.346 | 0.460 | 0.62 | 0.24 s |

Trackpad pull recognition additionally requires at least four active contacts.
This prevents a stationary two-finger press from becoming a pull. Video 2 alone
maps movement at or above `0.72` to a failure snap and rearms below `0.38`.
Video 3 alone enables bar-pung. Videos 5 through 11 keep it disabled because no
inflated sheet was observed in those references.

## Videos 9-11 Analysis

| Video | Duration | Hand coverage | Gestures | Relative pressure median / high | Movement median / high | Accepted audio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 9 | 30.67 s | 97.39% | 43 knead, 32 stretch | 0.745 / 0.979 | 0.265 / 0.703 | 30 |
| 10 | 22.53 s | 100% | 28 knead, 15 stretch, 1 press | 0.561 / 0.946 | 0.142 / 0.376 | 9 |
| 11 | 38.01 s | 88.25% | 59 knead, 31 stretch, 1 press | 0.692 / 1.000 | 0.210 / 0.492 | 22 |

Video 11 has lower full-video coverage because the single hand and tiny
material leave the frame in several sections. Every accepted audio timestamp
still overlaps visible material contact.

All 61 accepted clips from Videos 9-11 were checked against their event frames.
Faster Whisper small Korean VAD found zero speech segments in every source.
The 12 loudest clips per video were also reviewed with AudioSet AST labels; the
dominant labels were transient categories such as finger snap, crunch, scrape,
friction, and sound effect. No music, voice, cable impact, or table strike was
accepted after cross-modal review.

## Same-Material Mixing

Video 9 presses begin with low wet-friction body audio. Above intensity `0.28`,
clay snaps or suction can be added with probability rising from `0.16` to
`0.72`, at `0.18...0.42` of the primary level and a `9...30 ms` delay.

Video 10 uses micro-pops as the primary response. Above intensity `0.42`, one
of the two firmer glossy snaps can be added with probability rising from `0.10`
to `0.58`, at `0.16...0.34` of the primary level and a `7...24 ms` delay.

Video 11 presses begin with quiet body friction. Above intensity `0.24`, a bead
pop, suction, cluster, or compact snap can be added with probability rising from
`0.18` to `0.76`, at `0.16...0.38` of the primary level and a `6...22 ms`
delay.

Pull gestures reverse the emphasis for Videos 9 and 11: the sharper material
texture is primary and a quieter body-friction layer is optional. Release uses
only the material's pop or texture pool. Shuffle bags exhaust every variation
before repeating, and the profile cooldown limits dense overlap.

## Physical Calibration Still Required

1. Record each profile on an Apple Silicon MacBook at light, medium, and firm
   pressure.
2. Verify exact two-finger retention during pressure-only updates.
3. Tune the gain and layer probability while listening through speakers and
   headphones.
4. Compare camera gesture labels against the filmed action, especially the tiny
   one-hand Video 11 interaction.
5. Confirm macOS system gestures remain suppressed inside the active Squish
   Surface, disabling conflicting Trackpad settings when the OS intercepts them.
