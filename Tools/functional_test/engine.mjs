const clamp = (value, minimum = 0, maximum = 1) =>
  Math.min(Math.max(Number(value) || 0, minimum), maximum);

export const TrackpadMode = Object.freeze({
  SLIME: "sixFingerSlime",
  WAX: "twoThumbWaxCrush",
});

export const SoundKind = Object.freeze({
  SLIME_KNEAD: "slimeKnead",
  SLIME_STRETCH: "slimeStretch",
  SLIME_BUBBLE: "slimeBubble",
  SLIME_STRETCH_FAILURE: "slimeStretchFailure",
  SLIME_RELEASE: "slimeRelease",
  WAX_PRESS: "waxPress",
  WAX_CRACK: "waxCrack",
  WAX_CRUSH: "waxCrush",
});

export const SOUND_TITLES = Object.freeze({
  [SoundKind.SLIME_KNEAD]: "Slime knead",
  [SoundKind.SLIME_STRETCH]: "Slime stretch",
  [SoundKind.SLIME_BUBBLE]: "Slime bar-pung",
  [SoundKind.SLIME_STRETCH_FAILURE]: "Stretch too fast",
  [SoundKind.SLIME_RELEASE]: "Slime release",
  [SoundKind.WAX_PRESS]: "Wax press",
  [SoundKind.WAX_CRACK]: "Wax crack",
  [SoundKind.WAX_CRUSH]: "Wax crush",
});

const STANDARD_WAX_RULES = Object.freeze({
  minimumContactCount: 2,
  pressPressureThreshold: 0.3,
  crackPressureThreshold: 0.55,
  crushPressureThreshold: 0.78,
  crackMovementThreshold: 0.28,
  crackClosingThreshold: 0.1,
  crushClosingThreshold: 0.2,
  crackPressureJumpThreshold: 0.12,
  crushPressureJumpThreshold: 0.35,
  repeatedCrackImpulseThreshold: 0.1,
  repeatedCrackCooldown: 0.16,
  pressSoundPackId: null,
  crackSoundPackId: null,
  crushSoundPackId: null,
});

const PASTEL_WAX_RULES = Object.freeze({
  minimumContactCount: 2,
  pressPressureThreshold: 0.18,
  crackPressureThreshold: 0.43,
  crushPressureThreshold: 0.74,
  crackMovementThreshold: 0.16,
  crackClosingThreshold: 0.06,
  crushClosingThreshold: 0.14,
  crackPressureJumpThreshold: 0.09,
  crushPressureJumpThreshold: 0.26,
  repeatedCrackImpulseThreshold: 0.08,
  repeatedCrackCooldown: 0.14,
  pressSoundPackId: "pastel-wax-video-4-press",
  crackSoundPackId: "pastel-wax-video-4-crack",
  crushSoundPackId: "pastel-wax-video-4-crush",
});

const baseRules = Object.freeze({
  style: "elastic",
  minimumFingerCount: 3,
  stretchMovementThreshold: 0.16,
  fastStretchFailureMovementThreshold: null,
  fastStretchFailureResetThreshold: 0.38,
  fastStretchFailureCooldown: 0.9,
  failureSoundPackId: null,
  failureGestureLabel: "Stretch too fast",
  kneadSoundPackId: null,
  stretchSoundPackId: null,
  releaseSoundPackId: null,
  kneadSecondarySoundLayer: null,
  stretchSecondarySoundLayer: null,
  releaseSecondarySoundLayer: null,
  bubbleGesture: null,
  waxInteraction: null,
  volumeScale: 1,
  minimumSoundInterval: 0,
  interactionSummary: "",
});

const rules = (overrides = {}) =>
  Object.freeze({
    ...baseRules,
    ...overrides,
    waxInteraction: overrides.waxInteraction
      ? Object.freeze({ ...overrides.waxInteraction })
      : null,
    bubbleGesture: overrides.bubbleGesture
      ? Object.freeze({ ...overrides.bubbleGesture })
      : null,
  });

const secondaryLayer = (soundPackId, values) =>
  Object.freeze({ soundPackId, ...values });

export const INTERACTION_RULES = Object.freeze({
  standard: rules({
    interactionSummary: "Knead, press, and stretch with three to six fingers.",
  }),
  doctorPutty: rules({
    style: "densePutty",
    fastStretchFailureMovementThreshold: 0.72,
    failureSoundPackId: "doctor-putty-failure",
    failureGestureLabel: "Doctor Putty snapped: stretch too fast",
    interactionSummary:
      "Stretch slowly. Pulling too fast breaks the putty and plays a failure snap.",
  }),
  clearVideo3: rules({
    stretchMovementThreshold: 0.14,
    kneadSoundPackId: "clear-video-3-knead",
    stretchSoundPackId: "clear-video-3-stretch",
    bubbleGesture: {
      minimumFingerCount: 5,
      armSpreadThreshold: 0.6,
      minimumSealMovement: 0.1,
      minimumSealPressure: 0.3,
      minimumSpreadDrop: 0.16,
      maximumDuration: 1.25,
      cooldown: 1.2,
      soundPackId: "clear-video-3-stretch",
      gestureLabel: "Bar-pung seal",
    },
    volumeScale: 0.86,
    interactionSummary:
      "Press with three to six fingers, stretch broadly, then close and press to seal a bar-pung.",
  }),
  waxStandard: rules({
    style: "densePutty",
    minimumFingerCount: 2,
    stretchMovementThreshold: 0.18,
    waxInteraction: STANDARD_WAX_RULES,
    interactionSummary:
      "Press inward with two opposing contacts, then increase pressure to crack and crush the wax shell.",
  }),
  pastelWaxVideo4: rules({
    style: "densePutty",
    minimumFingerCount: 2,
    stretchMovementThreshold: 0.18,
    waxInteraction: PASTEL_WAX_RULES,
    volumeScale: 0.92,
    interactionSummary:
      "Use two opposing contacts. Light pressure presses, rising pressure cracks, and a firm squeeze crushes.",
  }),
  whitePuttyVideo5: rules({
    style: "densePutty",
    stretchMovementThreshold: 0.2,
    kneadSoundPackId: "white-putty-video-5-knead",
    stretchSoundPackId: "white-putty-video-5-stretch",
    releaseSoundPackId: "white-putty-video-5-stretch",
    volumeScale: 0.68,
    minimumSoundInterval: 0.38,
    interactionSummary:
      "Use compact pinches, controlled short pulls, folds, and firm presses.",
  }),
  denseWhiteClayVideo7: rules({
    style: "densePutty",
    minimumFingerCount: 2,
    stretchMovementThreshold: 0.16,
    kneadSoundPackId: "dense-white-clay-video-7-knead",
    stretchSoundPackId: "dense-white-clay-video-7-stretch",
    releaseSoundPackId: "dense-white-clay-video-7-stretch",
    volumeScale: 0.66,
    minimumSoundInterval: 0.32,
    interactionSummary:
      "Press with two contacts and use four or more for short controlled pulls.",
  }),
  pinkGummyJellyVideo8: rules({
    minimumFingerCount: 2,
    stretchMovementThreshold: 0.14,
    kneadSoundPackId: "pink-gummy-jelly-video-8-knead",
    stretchSoundPackId: "pink-gummy-jelly-video-8-stretch",
    releaseSoundPackId: "pink-gummy-jelly-video-8-stretch",
    volumeScale: 0.68,
    minimumSoundInterval: 0.3,
    interactionSummary:
      "Pinch with two or more contacts and use four or more for pulls and folds.",
  }),
  aeratedClearVideo6: rules({
    minimumFingerCount: 2,
    stretchMovementThreshold: 0.14,
    kneadSoundPackId: "aerated-clear-video-6-knead",
    stretchSoundPackId: "aerated-clear-video-6-stretch",
    releaseSoundPackId: "aerated-clear-video-6-stretch",
    volumeScale: 0.72,
    minimumSoundInterval: 0.24,
    interactionSummary:
      "Poke with two or more contacts and pull broadly to form a membrane.",
  }),
  whitePokePuttyVideo9: rules({
    style: "densePutty",
    minimumFingerCount: 2,
    stretchMovementThreshold: 0.18,
    kneadSoundPackId: "white-poke-putty-video-9-body",
    stretchSoundPackId: "white-poke-putty-video-9-texture",
    releaseSoundPackId: "white-poke-putty-video-9-texture",
    kneadSecondarySoundLayer: secondaryLayer(
      "white-poke-putty-video-9-texture",
      {
        minimumIntensity: 0.28,
        probabilityAtMinimum: 0.16,
        probabilityAtMaximum: 0.72,
        volumeScaleAtMinimum: 0.18,
        volumeScaleAtMaximum: 0.42,
        minimumDelayMilliseconds: 9,
        maximumDelayMilliseconds: 30,
        rateOffset: 0.015,
      },
    ),
    stretchSecondarySoundLayer: secondaryLayer(
      "white-poke-putty-video-9-body",
      {
        minimumIntensity: 0.34,
        probabilityAtMinimum: 0.12,
        probabilityAtMaximum: 0.46,
        volumeScaleAtMinimum: 0.14,
        volumeScaleAtMaximum: 0.3,
        minimumDelayMilliseconds: 14,
        maximumDelayMilliseconds: 38,
        rateOffset: -0.02,
      },
    ),
    volumeScale: 0.66,
    minimumSoundInterval: 0.28,
    interactionSummary:
      "Use two to six contacts for deep pokes, folds, and controlled pulls.",
  }),
  orangeGlossyVideo10: rules({
    minimumFingerCount: 2,
    stretchMovementThreshold: 0.16,
    kneadSoundPackId: "orange-glossy-video-10-pop",
    stretchSoundPackId: "orange-glossy-video-10-pop",
    releaseSoundPackId: "orange-glossy-video-10-snap",
    kneadSecondarySoundLayer: secondaryLayer(
      "orange-glossy-video-10-snap",
      {
        minimumIntensity: 0.42,
        probabilityAtMinimum: 0.1,
        probabilityAtMaximum: 0.58,
        volumeScaleAtMinimum: 0.16,
        volumeScaleAtMaximum: 0.34,
        minimumDelayMilliseconds: 7,
        maximumDelayMilliseconds: 24,
        rateOffset: -0.01,
      },
    ),
    stretchSecondarySoundLayer: secondaryLayer(
      "orange-glossy-video-10-snap",
      {
        minimumIntensity: 0.48,
        probabilityAtMinimum: 0.12,
        probabilityAtMaximum: 0.52,
        volumeScaleAtMinimum: 0.16,
        volumeScaleAtMaximum: 0.32,
        minimumDelayMilliseconds: 10,
        maximumDelayMilliseconds: 28,
        rateOffset: -0.015,
      },
    ),
    volumeScale: 0.64,
    minimumSoundInterval: 0.26,
    interactionSummary:
      "Fold and squeeze with two or more contacts, then make repeated pokes.",
  }),
  greenMicroBeadVideo11: rules({
    style: "textured",
    minimumFingerCount: 2,
    stretchMovementThreshold: 0.16,
    kneadSoundPackId: "green-micro-bead-video-11-body",
    stretchSoundPackId: "green-micro-bead-video-11-pop",
    releaseSoundPackId: "green-micro-bead-video-11-pop",
    kneadSecondarySoundLayer: secondaryLayer(
      "green-micro-bead-video-11-pop",
      {
        minimumIntensity: 0.24,
        probabilityAtMinimum: 0.18,
        probabilityAtMaximum: 0.76,
        volumeScaleAtMinimum: 0.16,
        volumeScaleAtMaximum: 0.38,
        minimumDelayMilliseconds: 6,
        maximumDelayMilliseconds: 22,
        rateOffset: 0.025,
      },
    ),
    stretchSecondarySoundLayer: secondaryLayer(
      "green-micro-bead-video-11-body",
      {
        minimumIntensity: 0.32,
        probabilityAtMinimum: 0.1,
        probabilityAtMaximum: 0.4,
        volumeScaleAtMinimum: 0.12,
        volumeScaleAtMaximum: 0.26,
        minimumDelayMilliseconds: 12,
        maximumDelayMilliseconds: 34,
        rateOffset: -0.02,
      },
    ),
    volumeScale: 0.62,
    minimumSoundInterval: 0.24,
    interactionSummary:
      "Use precise two-contact pinches and short presses for compact bead pops.",
  }),
});

const densePuttyDefaults = rules({
  style: "densePutty",
  minimumFingerCount: 3,
  stretchMovementThreshold: 0.18,
  interactionSummary:
    "Knead with steady pressure and stretch at a controlled speed.",
});

const cloudDefaults = rules({
  style: "softDrizzle",
  minimumFingerCount: 3,
  stretchMovementThreshold: 0.14,
  interactionSummary: "Use broad, slow pulls and light pressure.",
});

const texturedDefaults = rules({
  style: "textured",
  minimumFingerCount: 3,
  stretchMovementThreshold: 0.2,
  interactionSummary: "Press and fold to emphasize the textured inclusions.",
});

const profile = (id, displayName, category, interactionRules, tuning = {}) =>
  Object.freeze({
    id,
    displayName,
    category,
    mode: category === "waxShell" ? TrackpadMode.WAX : TrackpadMode.SLIME,
    rules: interactionRules,
    tuning: Object.freeze({
      response: clamp(tuning.response ?? 1, 0.5, 1.75),
      soundDensity: clamp(tuning.soundDensity ?? 1, 0.5, 2),
    }),
  });

export const MATERIAL_PROFILES = Object.freeze([
  profile("clear", "Clear Slime", "clear", INTERACTION_RULES.standard),
  profile(
    "clear-video-3",
    "Clear Slime (Video 3)",
    "clear",
    INTERACTION_RULES.clearVideo3,
    { response: 0.96, soundDensity: 1.08 },
  ),
  profile(
    "aerated-clear-slime-video-6",
    "Aerated Clear Slime (Video 6)",
    "clear",
    INTERACTION_RULES.aeratedClearVideo6,
    { response: 0.96, soundDensity: 0.95 },
  ),
  profile(
    "thick-glossy",
    "Thick & Glossy Slime",
    "thickGlossy",
    INTERACTION_RULES.standard,
  ),
  profile(
    "doctor-putty-pink",
    "Doctor Putty (Pastel Pink)",
    "butterClay",
    INTERACTION_RULES.doctorPutty,
  ),
  profile(
    "white-dense-putty-video-5",
    "White Dense Putty (Video 5)",
    "butterClay",
    INTERACTION_RULES.whitePuttyVideo5,
    { response: 0.92, soundDensity: 0.88 },
  ),
  profile(
    "dense-white-clay-slime-video-7",
    "Dense White Clay Slime (Video 7)",
    "butterClay",
    INTERACTION_RULES.denseWhiteClayVideo7,
    { response: 1, soundDensity: 0.86 },
  ),
  profile(
    "pastel-wax-shell-video-4",
    "Pastel Wax Shell Slime (Video 4)",
    "waxShell",
    INTERACTION_RULES.pastelWaxVideo4,
    { response: 1.08, soundDensity: 1.18 },
  ),
  profile("butter-clay", "Butter / Clay Slime", "butterClay", densePuttyDefaults),
  profile("cloud", "Cloud Slime", "cloud", cloudDefaults),
  profile("jelly", "Jelly Slime", "jelly", INTERACTION_RULES.standard),
  profile(
    "pink-gummy-jelly-slime-video-8",
    "Pink Gummy Jelly Slime (Video 8)",
    "jelly",
    INTERACTION_RULES.pinkGummyJellyVideo8,
    { response: 0.96, soundDensity: 0.94 },
  ),
  profile(
    "white-poke-putty-video-9",
    "White Poke Putty (Video 9)",
    "butterClay",
    INTERACTION_RULES.whitePokePuttyVideo9,
    { response: 0.9, soundDensity: 0.92 },
  ),
  profile(
    "orange-glossy-slime-video-10",
    "Orange Glossy Slime (Video 10)",
    "thickGlossy",
    INTERACTION_RULES.orangeGlossyVideo10,
  ),
  profile(
    "green-micro-bead-floam-video-11",
    "Green Micro-Bead Floam (Video 11)",
    "floam",
    INTERACTION_RULES.greenMicroBeadVideo11,
  ),
  profile("icee", "Icee Slime", "icee", INTERACTION_RULES.standard),
  profile("floam", "Floam / Bead Slime", "floam", texturedDefaults),
  profile("crunchy", "Crunchy Slime", "crunchy", texturedDefaults),
  profile(
    "wax-shell-dark-brown-yellow",
    "Dark Brown Wax Shell / Yellow Slime Core",
    "waxShell",
    INTERACTION_RULES.waxStandard,
  ),
  profile(
    "wax-shell",
    "Generic Wax Shell Slime",
    "waxShell",
    INTERACTION_RULES.waxStandard,
  ),
]);

export const getProfile = (id) =>
  MATERIAL_PROFILES.find((candidate) => candidate.id === id) ??
  MATERIAL_PROFILES.find((candidate) => candidate.id === "doctor-putty-pink");

const soundPackForWax = (waxRules, kind) => {
  if (kind === SoundKind.WAX_PRESS) return waxRules.pressSoundPackId;
  if (kind === SoundKind.WAX_CRACK) return waxRules.crackSoundPackId;
  if (kind === SoundKind.WAX_CRUSH) return waxRules.crushSoundPackId;
  return null;
};

const soundPackForKind = (interactionRules, kind) => {
  if (kind === SoundKind.SLIME_KNEAD) return interactionRules.kneadSoundPackId;
  if (kind === SoundKind.SLIME_STRETCH) return interactionRules.stretchSoundPackId;
  if (kind === SoundKind.SLIME_BUBBLE) {
    return interactionRules.bubbleGesture?.soundPackId ?? null;
  }
  if (kind === SoundKind.SLIME_RELEASE) return interactionRules.releaseSoundPackId;
  if (kind === SoundKind.SLIME_STRETCH_FAILURE) {
    return interactionRules.failureSoundPackId;
  }
  return soundPackForWax(
    interactionRules.waxInteraction ?? STANDARD_WAX_RULES,
    kind,
  );
};

const secondaryLayerForKind = (interactionRules, kind) => {
  if (kind === SoundKind.SLIME_KNEAD) {
    return interactionRules.kneadSecondarySoundLayer;
  }
  if (kind === SoundKind.SLIME_STRETCH) {
    return interactionRules.stretchSecondarySoundLayer;
  }
  if (kind === SoundKind.SLIME_RELEASE) {
    return interactionRules.releaseSecondarySoundLayer;
  }
  return null;
};

export class TrackpadGestureEngine {
  constructor() {
    this.reset();
  }

  reset() {
    this.lastTriggerTimes = new Map();
    this.previousFingerCount = 0;
    this.previousPressure = 0;
    this.previousSpread = 0;
    this.previousWaxSignal = 0;
    this.waxStage = 0;
    this.slimeStretchFailureLatched = false;
    this.resetSlimeBubble();
    this.lastInteractionTriggerTime = Number.NEGATIVE_INFINITY;
    this.activeMinimumSoundInterval = 0;
  }

  get isBarPungPrepared() {
    return this.slimeBubbleArmTime !== null;
  }

  evaluate({
    mode,
    fingerCount,
    pressure,
    movement,
    spread,
    timestamp,
    tuning = { response: 1, soundDensity: 1 },
    interactionRules = INTERACTION_RULES.standard,
  }) {
    const safeTuning = {
      response: clamp(tuning.response ?? 1, 0.5, 1.75),
      soundDensity: clamp(tuning.soundDensity ?? 1, 0.5, 2),
    };
    const responsivePressure = clamp(pressure) * safeTuning.response;
    const responsiveMovement = clamp(movement) * safeTuning.response;
    this.activeMinimumSoundInterval = clamp(
      interactionRules.minimumSoundInterval ?? 0,
      0,
      2,
    );

    const input = {
      fingerCount: Math.max(0, Math.trunc(Number(fingerCount) || 0)),
      pressure: clamp(responsivePressure),
      movement: clamp(responsiveMovement),
      spread: clamp(spread),
      timestamp: Number(timestamp) || 0,
      soundDensity: safeTuning.soundDensity,
      interactionRules,
    };

    return mode === TrackpadMode.WAX
      ? this.evaluateWax(input)
      : this.evaluateSlime(input);
  }

  evaluateSlime(input) {
    const {
      fingerCount,
      pressure,
      movement,
      spread,
      timestamp,
      soundDensity,
      interactionRules,
    } = input;
    const fingerFactor = clamp(Math.min(fingerCount, 6) / 6);
    const liveIntensity = clamp(
      fingerFactor * 0.4 + pressure * 0.42 + movement * 0.18,
    );
    const pressureDelta = Math.abs(pressure - this.previousPressure);
    const spreadDelta = Math.abs(spread - this.previousSpread);
    const minimumFingerCount = interactionRules.minimumFingerCount;
    const isInitialContact =
      this.previousFingerCount < minimumFingerCount &&
      fingerCount >= minimumFingerCount;
    const finish = (result) => {
      this.previousFingerCount = fingerCount;
      this.previousPressure = pressure;
      this.previousSpread = spread;
      return result;
    };

    if (
      fingerCount < minimumFingerCount ||
      movement <= interactionRules.fastStretchFailureResetThreshold
    ) {
      this.slimeStretchFailureLatched = false;
    }

    const bubble = interactionRules.bubbleGesture;
    if (bubble) {
      if (
        this.slimeBubbleArmTime !== null &&
        timestamp - this.slimeBubbleArmTime > bubble.maximumDuration
      ) {
        this.resetSlimeBubble();
      }

      if (fingerCount < bubble.minimumFingerCount) {
        this.resetSlimeBubble();
      } else if (this.slimeBubbleArmTime !== null) {
        this.slimeBubbleMaximumSpread = Math.max(
          this.slimeBubbleMaximumSpread,
          spread,
        );
        const spreadDrop = Math.max(
          0,
          this.slimeBubbleMaximumSpread - spread,
        );
        const isSeal =
          timestamp > this.slimeBubbleArmTime &&
          movement >= bubble.minimumSealMovement &&
          pressure >= bubble.minimumSealPressure &&
          spreadDrop >= bubble.minimumSpreadDrop;
        if (isSeal) {
          const sealProgress = clamp(
            spreadDrop / Math.max(bubble.minimumSpreadDrop, 0.01),
          );
          const intensity = clamp(
            pressure * 0.42 + movement * 0.33 + sealProgress * 0.25,
          );
          this.resetSlimeBubble();
          return finish(
            this.triggerIfReady({
              kind: SoundKind.SLIME_BUBBLE,
              intensity,
              label: bubble.gestureLabel,
              liveIntensity,
              timestamp,
              interval: this.densityAdjusted(bubble.cooldown, soundDensity),
              soundPackIdOverride: bubble.soundPackId,
              volumeScale: interactionRules.volumeScale,
            }),
          );
        }
      } else if (spread >= bubble.armSpreadThreshold) {
        this.slimeBubbleArmTime = timestamp;
        this.slimeBubbleMaximumSpread = spread;
      }
    } else {
      this.resetSlimeBubble();
    }

    if (
      this.previousFingerCount >= minimumFingerCount &&
      fingerCount === 0 &&
      this.previousPressure >= 0.18
    ) {
      const intensity = clamp(this.previousPressure * 0.8 + 0.2);
      return finish(
        this.triggerIfReady({
          kind: SoundKind.SLIME_RELEASE,
          intensity,
          label: "Slime release",
          liveIntensity,
          timestamp,
          interval: this.densityAdjusted(0.1, soundDensity),
          soundPackIdOverride: interactionRules.releaseSoundPackId,
          volumeScale: interactionRules.volumeScale,
          secondarySoundLayer: secondaryLayerForKind(
            interactionRules,
            SoundKind.SLIME_RELEASE,
          ),
        }),
      );
    }

    if (fingerCount < minimumFingerCount || liveIntensity < 0.28) {
      return finish({ liveIntensity, trigger: null });
    }

    const hasTextureChange =
      isInitialContact ||
      movement >= 0.025 ||
      pressureDelta >= 0.018 ||
      spreadDelta >= 0.025;
    if (!hasTextureChange) {
      return finish({ liveIntensity, trigger: null });
    }

    const isStretching =
      movement >= interactionRules.stretchMovementThreshold &&
      pressure <= 0.72 &&
      fingerCount >= Math.max(4, minimumFingerCount);
    const failureThreshold =
      interactionRules.fastStretchFailureMovementThreshold;
    if (
      isStretching &&
      failureThreshold !== null &&
      movement >= failureThreshold &&
      !this.slimeStretchFailureLatched
    ) {
      const failureProgress = clamp(
        (movement - failureThreshold) / Math.max(0.01, 1 - failureThreshold),
      );
      const evaluation = this.triggerIfReady({
        kind: SoundKind.SLIME_STRETCH_FAILURE,
        intensity: clamp(0.7 + failureProgress * 0.3),
        label: interactionRules.failureGestureLabel,
        liveIntensity,
        timestamp,
        interval: this.densityAdjusted(
          interactionRules.fastStretchFailureCooldown,
          soundDensity,
        ),
        soundPackIdOverride: interactionRules.failureSoundPackId,
        volumeScale: interactionRules.volumeScale,
      });
      if (evaluation.trigger) this.slimeStretchFailureLatched = true;
      return finish(evaluation);
    }

    const kind = isStretching
      ? SoundKind.SLIME_STRETCH
      : SoundKind.SLIME_KNEAD;
    const baseInterval = Math.max(
      0.07,
      (isStretching ? 0.22 : 0.28) - liveIntensity * 0.16,
    );
    const label = isStretching
      ? "Slime stretch"
      : fingerCount >= 6
        ? "6-finger slime press"
        : "Slime knead";

    return finish(
      this.triggerIfReady({
        kind,
        intensity: liveIntensity,
        label,
        liveIntensity,
        timestamp,
        interval: this.densityAdjusted(baseInterval, soundDensity),
        soundPackIdOverride: soundPackForKind(interactionRules, kind),
        volumeScale: interactionRules.volumeScale,
        secondarySoundLayer: secondaryLayerForKind(interactionRules, kind),
      }),
    );
  }

  evaluateWax(input) {
    const {
      fingerCount,
      pressure,
      movement,
      spread,
      timestamp,
      soundDensity,
      interactionRules,
    } = input;
    const wax = interactionRules.waxInteraction ?? STANDARD_WAX_RULES;
    const hasRequiredContacts = fingerCount === wax.minimumContactCount;
    const closingSpeed =
      this.previousFingerCount === wax.minimumContactCount
        ? Math.max(0, this.previousSpread - spread)
        : 0;
    const deformationSignal = clamp(
      movement * 0.52 +
        Math.min(1, closingSpeed * 2.4) * 0.34 +
        (1 - spread) * 0.14,
    );
    const waxSignal = Math.max(pressure, deformationSignal);
    const liveIntensity = clamp(
      (hasRequiredContacts ? 1 : 0) * 0.18 + waxSignal * 0.82,
    );
    const pressureJump =
      this.previousFingerCount === wax.minimumContactCount
        ? Math.max(
            pressure - this.previousPressure,
            waxSignal - this.previousWaxSignal,
          )
        : 0;
    const finish = (result) => {
      this.previousFingerCount = fingerCount;
      this.previousPressure = pressure;
      this.previousSpread = spread;
      this.previousWaxSignal = waxSignal;
      return result;
    };

    if (!hasRequiredContacts) {
      if (fingerCount === 0 && pressure <= 0.05) this.waxStage = 0;
      return finish({ liveIntensity, trigger: null });
    }

    let nextStage = 0;
    if (
      waxSignal >= wax.crushPressureThreshold ||
      pressureJump >= wax.crushPressureJumpThreshold ||
      (closingSpeed >= wax.crushClosingThreshold &&
        pressure >= wax.crackPressureThreshold)
    ) {
      nextStage = 3;
    } else if (
      waxSignal >= wax.crackPressureThreshold ||
      movement >= wax.crackMovementThreshold ||
      closingSpeed >= wax.crackClosingThreshold
    ) {
      nextStage = 2;
    } else if (waxSignal >= wax.pressPressureThreshold) {
      nextStage = 1;
    } else {
      return finish({ liveIntensity, trigger: null });
    }

    if (nextStage === 2 && this.waxStage === 2) {
      const repeatedCrackImpulse = Math.max(
        pressureJump,
        closingSpeed,
        Math.abs(waxSignal - this.previousWaxSignal),
      );
      if (repeatedCrackImpulse < wax.repeatedCrackImpulseThreshold) {
        return finish({ liveIntensity, trigger: null });
      }
      return finish(
        this.triggerIfReady({
          kind: SoundKind.WAX_CRACK,
          intensity: liveIntensity,
          label: "Wax micro-crack",
          liveIntensity,
          timestamp,
          interval: this.densityAdjusted(
            wax.repeatedCrackCooldown,
            soundDensity,
          ),
          soundPackIdOverride: wax.crackSoundPackId,
          volumeScale: interactionRules.volumeScale,
        }),
      );
    }

    if (nextStage <= this.waxStage) {
      return finish({ liveIntensity, trigger: null });
    }
    this.waxStage = nextStage;

    const kind =
      nextStage === 1
        ? SoundKind.WAX_PRESS
        : nextStage === 2
          ? SoundKind.WAX_CRACK
          : SoundKind.WAX_CRUSH;
    const baseInterval =
      nextStage === 1
        ? 0.24
        : nextStage === 2
          ? Math.max(0.13, 0.34 - liveIntensity * 0.18)
          : Math.max(0.11, 0.48 - liveIntensity * 0.25);

    return finish(
      this.triggerIfReady({
        kind,
        intensity: liveIntensity,
        label: SOUND_TITLES[kind],
        liveIntensity,
        timestamp,
        interval: this.densityAdjusted(baseInterval, soundDensity),
        soundPackIdOverride: soundPackForWax(wax, kind),
        volumeScale: interactionRules.volumeScale,
      }),
    );
  }

  triggerIfReady({
    kind,
    intensity,
    label,
    liveIntensity,
    timestamp,
    interval,
    soundPackIdOverride = null,
    volumeScale = 1,
    secondarySoundLayer = null,
  }) {
    const lastKindTime =
      this.lastTriggerTimes.get(kind) ?? Number.NEGATIVE_INFINITY;
    if (
      timestamp - lastKindTime < interval ||
      timestamp - this.lastInteractionTriggerTime <
        this.activeMinimumSoundInterval
    ) {
      return { liveIntensity, trigger: null };
    }

    this.lastTriggerTimes.set(kind, timestamp);
    this.lastInteractionTriggerTime = timestamp;
    return {
      liveIntensity,
      trigger: {
        kind,
        intensity: clamp(intensity),
        label,
        soundPackIdOverride,
        volumeScale: clamp(volumeScale ?? 1, 0.1, 1),
        secondarySoundLayer,
      },
    };
  }

  resetSlimeBubble() {
    this.slimeBubbleArmTime = null;
    this.slimeBubbleMaximumSpread = 0;
  }

  densityAdjusted(interval, soundDensity) {
    return interval / clamp(soundDensity, 0.5, 2);
  }
}

export const audioResponse = (kind, intensity, masterVolume = 1) => {
  const safeIntensity = clamp(intensity);
  let packId;
  let rate;
  let volumeBoost;

  if (kind === SoundKind.SLIME_KNEAD) {
    [packId, rate, volumeBoost] = ["slime", 0.82 + safeIntensity * 0.34, 0];
  } else if (kind === SoundKind.SLIME_STRETCH) {
    [packId, rate, volumeBoost] = [
      "slime",
      0.64 + safeIntensity * 0.26,
      -0.04,
    ];
  } else if (kind === SoundKind.SLIME_BUBBLE) {
    [packId, rate, volumeBoost] = [
      "bubble",
      0.74 + safeIntensity * 0.28,
      0.02,
    ];
  } else if (kind === SoundKind.SLIME_STRETCH_FAILURE) {
    [packId, rate, volumeBoost] = [
      "pop",
      0.94 + safeIntensity * 0.18,
      0.08,
    ];
  } else if (kind === SoundKind.SLIME_RELEASE) {
    [packId, rate, volumeBoost] = [
      "pop",
      0.92 + safeIntensity * 0.24,
      -0.06,
    ];
  } else if (kind === SoundKind.WAX_PRESS) {
    [packId, rate, volumeBoost] = [
      "squishy",
      0.7 + safeIntensity * 0.28,
      -0.1,
    ];
  } else if (kind === SoundKind.WAX_CRACK) {
    [packId, rate, volumeBoost] = [
      "wax",
      0.88 + safeIntensity * 0.34,
      -0.02,
    ];
  } else {
    [packId, rate, volumeBoost] = [
      "wax",
      0.76 + safeIntensity * 0.58,
      0.06,
    ];
  }

  return {
    packId,
    rate: clamp(rate, 0.5, 1.5),
    volume:
      clamp(0.18 + safeIntensity * 0.82 + volumeBoost, 0.05, 1) *
      clamp(masterVolume),
  };
};

export const planSecondarySound = (
  soundLayer,
  intensity,
  probabilitySample = Math.random(),
  delaySample = Math.random(),
) => {
  if (!soundLayer) return null;
  const safeIntensity = clamp(intensity);
  if (safeIntensity < soundLayer.minimumIntensity) return null;

  const progress = clamp(
    (safeIntensity - soundLayer.minimumIntensity) /
      Math.max(0.001, 1 - soundLayer.minimumIntensity),
  );
  const probability =
    soundLayer.probabilityAtMinimum +
    (soundLayer.probabilityAtMaximum - soundLayer.probabilityAtMinimum) *
      progress;
  if (clamp(probabilitySample) > probability) return null;

  return {
    soundPackId: soundLayer.soundPackId,
    volumeScale:
      soundLayer.volumeScaleAtMinimum +
      (soundLayer.volumeScaleAtMaximum - soundLayer.volumeScaleAtMinimum) *
        progress,
    delayMilliseconds:
      soundLayer.minimumDelayMilliseconds +
      (soundLayer.maximumDelayMilliseconds -
        soundLayer.minimumDelayMilliseconds) *
        clamp(delaySample),
    rateOffset: clamp(soundLayer.rateOffset ?? 0, -0.25, 0.25),
  };
};

export class TrackpadSessionRecorder {
  constructor(maximumSampleCount = 36_000) {
    this.maximumSampleCount = Math.max(
      1,
      Math.trunc(Number(maximumSampleCount) || 1),
    );
    this.clear();
  }

  get hasRecording() {
    return this.samples.length > 0;
  }

  start({
    tuning = { response: 1, soundDensity: 1 },
    materialProfileId = null,
    at = new Date(),
  } = {}) {
    this.samples = [];
    this.events = [];
    this.startedAt = new Date(at);
    this.endedAt = null;
    this.tuning = {
      response: clamp(tuning.response ?? 1, 0.5, 1.75),
      sound_density: clamp(tuning.soundDensity ?? 1, 0.5, 2),
    };
    this.materialProfileId = materialProfileId;
    this.isAtCapacity = false;
    this.isRecording = true;
  }

  stop(at = new Date()) {
    if (!this.startedAt) return;
    this.endedAt = new Date(at);
    this.isRecording = false;
  }

  clear() {
    this.isRecording = false;
    this.isAtCapacity = false;
    this.samples = [];
    this.events = [];
    this.startedAt = null;
    this.endedAt = null;
    this.tuning = { response: 1, sound_density: 1 };
    this.materialProfileId = null;
  }

  append({
    mode,
    fingerCount,
    pressure,
    forceStage,
    movement,
    spread,
    intensity,
    touches = [],
    trigger = null,
    at = new Date(),
  }) {
    if (!this.isRecording || !this.startedAt) return;
    const relativeTime = Math.max(
      0,
      (new Date(at).getTime() - this.startedAt.getTime()) / 1000,
    );
    this.samples.push({
      relative_time: relativeTime,
      mode,
      finger_count: Math.max(0, Math.trunc(Number(fingerCount) || 0)),
      pressure: clamp(pressure),
      force_stage: Math.max(0, Math.trunc(Number(forceStage) || 0)),
      movement: clamp(movement),
      spread: clamp(spread),
      intensity: clamp(intensity),
      touches: touches.map((touch) => ({
        id: String(touch.id),
        x: clamp(touch.x),
        y: clamp(touch.y),
      })),
    });

    if (trigger) {
      this.events.push({
        relative_time: relativeTime,
        kind: trigger.kind,
        intensity: clamp(trigger.intensity),
      });
    }

    if (this.samples.length >= this.maximumSampleCount) {
      this.isAtCapacity = true;
      this.stop(at);
    }
  }

  toObject({
    appVersion = "functional-test",
    osVersion = "browser",
    architecture = "browser",
    endedAt = new Date(),
  } = {}) {
    if (!this.startedAt || this.samples.length === 0) {
      throw new Error("There are no recorded trackpad samples to export.");
    }
    return {
      schema_version: 2,
      app_version: appVersion,
      os_version: osVersion,
      architecture,
      started_at: this.startedAt.toISOString(),
      ended_at: (this.endedAt ?? new Date(endedAt)).toISOString(),
      tuning: this.tuning,
      material_profile_id: this.materialProfileId,
      samples: this.samples,
      events: this.events,
    };
  }

  encodedSession(metadata = {}) {
    return JSON.stringify(this.toObject(metadata), null, 2);
  }
}
