import assert from "node:assert/strict";
import { readdirSync, statSync } from "node:fs";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  INTERACTION_RULES,
  MATERIAL_PROFILES,
  SoundKind,
  TrackpadGestureEngine,
  TrackpadMode,
  TrackpadSessionRecorder,
  audioResponse,
  getProfile,
  planSecondarySound,
} from "./engine.mjs";

const evaluate = (
  engine,
  {
    mode = TrackpadMode.SLIME,
    fingerCount,
    pressure,
    movement,
    spread,
    timestamp,
    tuning = { response: 1, soundDensity: 1 },
    interactionRules = INTERACTION_RULES.standard,
  },
) =>
  engine.evaluate({
    mode,
    fingerCount,
    pressure,
    movement,
    spread,
    timestamp,
    tuning,
    interactionRules,
  });

test("standard slime recognizes knead, stretch, and release", () => {
  const kneadEngine = new TrackpadGestureEngine();
  const knead = evaluate(kneadEngine, {
    fingerCount: 6,
    pressure: 0.45,
    movement: 0.08,
    spread: 0.8,
    timestamp: 1,
  });
  assert.equal(knead.trigger?.kind, SoundKind.SLIME_KNEAD);
  assert.ok(knead.liveIntensity > 0.5);

  const stretchEngine = new TrackpadGestureEngine();
  const stretch = evaluate(stretchEngine, {
    fingerCount: 5,
    pressure: 0.42,
    movement: 0.32,
    spread: 0.7,
    timestamp: 1,
  });
  const release = evaluate(stretchEngine, {
    fingerCount: 0,
    pressure: 0,
    movement: 0,
    spread: 0,
    timestamp: 1.5,
  });
  assert.equal(stretch.trigger?.kind, SoundKind.SLIME_STRETCH);
  assert.equal(release.trigger?.kind, SoundKind.SLIME_RELEASE);
});

test("slime rejects too few fingers and stationary repeats", () => {
  const tooFew = evaluate(new TrackpadGestureEngine(), {
    fingerCount: 1,
    pressure: 0.9,
    movement: 0.9,
    spread: 0.2,
    timestamp: 1,
  });
  assert.equal(tooFew.trigger, null);

  const engine = new TrackpadGestureEngine();
  const first = evaluate(engine, {
    fingerCount: 6,
    pressure: 0.5,
    movement: 0.1,
    spread: 0.7,
    timestamp: 1,
  });
  const held = evaluate(engine, {
    fingerCount: 6,
    pressure: 0.5,
    movement: 0,
    spread: 0.7,
    timestamp: 2,
  });
  assert.equal(first.trigger?.kind, SoundKind.SLIME_KNEAD);
  assert.equal(held.trigger, null);
});

test("Video 3 bar-pung needs wide preparation and a pressured seal", () => {
  const engine = new TrackpadGestureEngine();
  evaluate(engine, {
    fingerCount: 6,
    pressure: 0.34,
    movement: 0.08,
    spread: 0.72,
    timestamp: 1,
    interactionRules: INTERACTION_RULES.clearVideo3,
  });
  assert.equal(engine.isBarPungPrepared, true);
  const seal = evaluate(engine, {
    fingerCount: 6,
    pressure: 0.52,
    movement: 0.18,
    spread: 0.48,
    timestamp: 1.35,
    interactionRules: INTERACTION_RULES.clearVideo3,
  });
  assert.equal(seal.trigger?.kind, SoundKind.SLIME_BUBBLE);
  assert.equal(seal.trigger?.label, "Bar-pung seal");
  assert.equal(seal.trigger?.soundPackIdOverride, "clear-video-3-stretch");
  assert.equal(seal.trigger?.volumeScale, 0.86);

  const noPressureEngine = new TrackpadGestureEngine();
  evaluate(noPressureEngine, {
    fingerCount: 6,
    pressure: 0.34,
    movement: 0.08,
    spread: 0.72,
    timestamp: 1,
    interactionRules: INTERACTION_RULES.clearVideo3,
  });
  const noPressure = evaluate(noPressureEngine, {
    fingerCount: 6,
    pressure: 0.12,
    movement: 0.18,
    spread: 0.48,
    timestamp: 1.35,
    interactionRules: INTERACTION_RULES.clearVideo3,
  });
  assert.notEqual(noPressure.trigger?.kind, SoundKind.SLIME_BUBBLE);
});

test("Doctor Putty failure remains latched until movement resets", () => {
  const engine = new TrackpadGestureEngine();
  const first = evaluate(engine, {
    fingerCount: 6,
    pressure: 0.42,
    movement: 0.82,
    spread: 0.75,
    timestamp: 1,
    interactionRules: INTERACTION_RULES.doctorPutty,
  });
  const held = evaluate(engine, {
    fingerCount: 6,
    pressure: 0.4,
    movement: 0.9,
    spread: 0.8,
    timestamp: 2,
    interactionRules: INTERACTION_RULES.doctorPutty,
  });
  evaluate(engine, {
    fingerCount: 6,
    pressure: 0.35,
    movement: 0.2,
    spread: 0.72,
    timestamp: 2.2,
    interactionRules: INTERACTION_RULES.doctorPutty,
  });
  const next = evaluate(engine, {
    fingerCount: 6,
    pressure: 0.42,
    movement: 0.84,
    spread: 0.82,
    timestamp: 3,
    interactionRules: INTERACTION_RULES.doctorPutty,
  });

  assert.equal(first.trigger?.kind, SoundKind.SLIME_STRETCH_FAILURE);
  assert.equal(first.trigger?.soundPackIdOverride, "doctor-putty-failure");
  assert.notEqual(held.trigger?.kind, SoundKind.SLIME_STRETCH_FAILURE);
  assert.equal(next.trigger?.kind, SoundKind.SLIME_STRETCH_FAILURE);
});

test("standard wax progresses monotonically and resets after release", () => {
  const stageEngine = new TrackpadGestureEngine();
  const press = evaluate(stageEngine, {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.52,
    movement: 0.1,
    spread: 0.35,
    timestamp: 1,
  });
  const crack = evaluate(stageEngine, {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.62,
    movement: 0.34,
    spread: 0.25,
    timestamp: 1.5,
  });
  assert.equal(press.trigger?.kind, SoundKind.WAX_PRESS);
  assert.equal(crack.trigger?.kind, SoundKind.WAX_CRACK);

  const crushEngine = new TrackpadGestureEngine();
  const firstCrush = evaluate(crushEngine, {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.9,
    movement: 0.3,
    spread: 0.2,
    timestamp: 1,
  });
  const heldCrush = evaluate(crushEngine, {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.95,
    movement: 0.4,
    spread: 0.1,
    timestamp: 2,
  });
  evaluate(crushEngine, {
    mode: TrackpadMode.WAX,
    fingerCount: 0,
    pressure: 0,
    movement: 0,
    spread: 0,
    timestamp: 2.2,
  });
  const nextCrush = evaluate(crushEngine, {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.9,
    movement: 0.3,
    spread: 0.2,
    timestamp: 3,
  });
  assert.equal(firstCrush.trigger?.kind, SoundKind.WAX_CRUSH);
  assert.equal(heldCrush.trigger, null);
  assert.equal(nextCrush.trigger?.kind, SoundKind.WAX_CRUSH);
});

test("Video 4 routes every wax stage to its material pack", () => {
  const engine = new TrackpadGestureEngine();
  const frames = [
    [1, 0.24, 0.02, 0.5],
    [1.3, 0.48, 0.1, 0.43],
    [1.6, 0.6, 0.08, 0.39],
    [1.9, 0.82, 0.12, 0.25],
  ].map(([timestamp, pressure, movement, spread]) =>
    evaluate(engine, {
      mode: TrackpadMode.WAX,
      fingerCount: 2,
      pressure,
      movement,
      spread,
      timestamp,
      interactionRules: INTERACTION_RULES.pastelWaxVideo4,
    }),
  );

  assert.deepEqual(
    frames.map((frame) => frame.trigger?.kind),
    [
      SoundKind.WAX_PRESS,
      SoundKind.WAX_CRACK,
      SoundKind.WAX_CRACK,
      SoundKind.WAX_CRUSH,
    ],
  );
  assert.deepEqual(
    frames.map((frame) => frame.trigger?.soundPackIdOverride),
    [
      "pastel-wax-video-4-press",
      "pastel-wax-video-4-crack",
      "pastel-wax-video-4-crack",
      "pastel-wax-video-4-crush",
    ],
  );
});

test("profile-wide minimum interval blocks chatter across sound kinds", () => {
  const engine = new TrackpadGestureEngine();
  const knead = evaluate(engine, {
    fingerCount: 5,
    pressure: 0.58,
    movement: 0.08,
    spread: 0.45,
    timestamp: 1,
    interactionRules: INTERACTION_RULES.whitePuttyVideo5,
  });
  const earlyStretch = evaluate(engine, {
    fingerCount: 5,
    pressure: 0.42,
    movement: 0.24,
    spread: 0.65,
    timestamp: 1.2,
    interactionRules: INTERACTION_RULES.whitePuttyVideo5,
  });
  const spacedStretch = evaluate(engine, {
    fingerCount: 5,
    pressure: 0.42,
    movement: 0.24,
    spread: 0.65,
    timestamp: 1.4,
    interactionRules: INTERACTION_RULES.whitePuttyVideo5,
  });
  assert.equal(knead.trigger?.kind, SoundKind.SLIME_KNEAD);
  assert.equal(earlyStretch.trigger, null);
  assert.equal(spacedStretch.trigger?.kind, SoundKind.SLIME_STRETCH);
});

test("Video 9 exposes its same-material secondary sound layer", () => {
  const engine = new TrackpadGestureEngine();
  const poke = evaluate(engine, {
    fingerCount: 2,
    pressure: 0.72,
    movement: 0.04,
    spread: 0.18,
    timestamp: 1,
    interactionRules: INTERACTION_RULES.whitePokePuttyVideo9,
  });
  assert.equal(poke.trigger?.kind, SoundKind.SLIME_KNEAD);
  assert.equal(
    poke.trigger?.soundPackIdOverride,
    "white-poke-putty-video-9-body",
  );
  assert.equal(
    poke.trigger?.secondarySoundLayer?.soundPackId,
    "white-poke-putty-video-9-texture",
  );
  assert.equal(poke.trigger?.volumeScale, 0.66);

  const plan = planSecondarySound(
    poke.trigger?.secondarySoundLayer,
    poke.trigger?.intensity ?? 0,
    0,
    0.5,
  );
  assert.equal(plan?.soundPackId, "white-poke-putty-video-9-texture");
  assert.ok((plan?.delayMilliseconds ?? 0) >= 9);
});

test("response tuning can recognize a quieter wax press", () => {
  const standard = evaluate(new TrackpadGestureEngine(), {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.25,
    movement: 0,
    spread: 0.5,
    timestamp: 1,
  });
  const responsive = evaluate(new TrackpadGestureEngine(), {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.25,
    movement: 0,
    spread: 0.5,
    timestamp: 1,
    tuning: { response: 1.75, soundDensity: 1 },
  });
  assert.equal(standard.trigger, null);
  assert.equal(responsive.trigger?.kind, SoundKind.WAX_PRESS);
});

test("engine reset clears stages and cooldowns", () => {
  const engine = new TrackpadGestureEngine();
  const first = evaluate(engine, {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.82,
    movement: 0.15,
    spread: 0.25,
    timestamp: 1,
  });
  engine.reset();
  const next = evaluate(engine, {
    mode: TrackpadMode.WAX,
    fingerCount: 2,
    pressure: 0.82,
    movement: 0.15,
    spread: 0.25,
    timestamp: 1.01,
  });
  assert.equal(first.trigger?.kind, SoundKind.WAX_CRUSH);
  assert.equal(next.trigger?.kind, SoundKind.WAX_CRUSH);
});

test("session recording exports schema v2 and clamps samples", () => {
  const recorder = new TrackpadSessionRecorder(10);
  const start = new Date("2026-01-01T00:00:00.000Z");
  recorder.start({
    tuning: { response: 1.2, soundDensity: 0.8 },
    materialProfileId: "doctor-putty-pink",
    at: start,
  });
  recorder.append({
    mode: TrackpadMode.SLIME,
    fingerCount: 6,
    pressure: 1.5,
    forceStage: 1,
    movement: 0.2,
    spread: 0.7,
    intensity: 0.65,
    touches: [{ id: "finger-1", x: -1, y: 2 }],
    trigger: {
      kind: SoundKind.SLIME_KNEAD,
      intensity: 0.7,
    },
    at: new Date(start.getTime() + 250),
  });
  recorder.stop(new Date(start.getTime() + 1000));

  const session = JSON.parse(recorder.encodedSession());
  assert.equal(session.schema_version, 2);
  assert.equal(session.material_profile_id, "doctor-putty-pink");
  assert.deepEqual(session.tuning, { response: 1.2, sound_density: 0.8 });
  assert.equal(session.samples.length, 1);
  assert.equal(session.events.length, 1);
  assert.equal(session.samples[0].relative_time, 0.25);
  assert.equal(session.samples[0].pressure, 1);
  assert.deepEqual(session.samples[0].touches[0], {
    id: "finger-1",
    x: 0,
    y: 1,
  });
});

test("session recorder stops at capacity and rejects empty export", () => {
  const empty = new TrackpadSessionRecorder();
  assert.throws(() => empty.encodedSession(), /no recorded trackpad samples/i);

  const recorder = new TrackpadSessionRecorder(2);
  const start = new Date("2026-01-01T00:00:00.000Z");
  recorder.start({ at: start });
  for (let index = 0; index < 3; index += 1) {
    recorder.append({
      mode: TrackpadMode.WAX,
      fingerCount: 2,
      pressure: 0.4,
      forceStage: 1,
      movement: 0.1,
      spread: 0.3,
      intensity: 0.5,
      at: new Date(start.getTime() + index * 100),
    });
  }
  assert.equal(recorder.samples.length, 2);
  assert.equal(recorder.isRecording, false);
  assert.equal(recorder.isAtCapacity, true);
});

test("material profiles and audio response expose expected runtime values", () => {
  const videoEleven = getProfile("green-micro-bead-floam-video-11");
  assert.equal(videoEleven.rules.minimumFingerCount, 2);
  assert.equal(videoEleven.rules.volumeScale, 0.62);

  const response = audioResponse(SoundKind.WAX_CRUSH, 1, 0.5);
  assert.equal(response.packId, "wax");
  assert.ok(Math.abs(response.rate - 1.34) < 0.0001);
  assert.equal(response.volume, 0.5);
});

test("every configured sound pack has playable bundled files", () => {
  const soundsRoot = fileURLToPath(
    new URL("../../Sources/SquishMac/Resources/Sounds/", import.meta.url),
  );
  const packIds = new Set(["slime", "bubble", "pop", "squishy", "wax"]);

  for (const material of MATERIAL_PROFILES) {
    const materialRules = material.rules;
    for (const key of [
      "kneadSoundPackId",
      "stretchSoundPackId",
      "releaseSoundPackId",
      "failureSoundPackId",
    ]) {
      if (materialRules[key]) packIds.add(materialRules[key]);
    }
    if (materialRules.bubbleGesture?.soundPackId) {
      packIds.add(materialRules.bubbleGesture.soundPackId);
    }
    for (const key of [
      "kneadSecondarySoundLayer",
      "stretchSecondarySoundLayer",
      "releaseSecondarySoundLayer",
    ]) {
      if (materialRules[key]?.soundPackId) {
        packIds.add(materialRules[key].soundPackId);
      }
    }
    for (const key of [
      "pressSoundPackId",
      "crackSoundPackId",
      "crushSoundPackId",
    ]) {
      if (materialRules.waxInteraction?.[key]) {
        packIds.add(materialRules.waxInteraction[key]);
      }
    }
  }

  for (const packId of packIds) {
    const packDirectory = new URL(
      `${encodeURIComponent(packId)}/`,
      new URL("../../Sources/SquishMac/Resources/Sounds/", import.meta.url),
    );
    const packPath = fileURLToPath(packDirectory);
    assert.equal(statSync(packPath).isDirectory(), true, packId);
    const files = readdirSync(packPath).filter((name) =>
      /\.(wav|mp3|m4a|aiff|aif)$/i.test(name),
    );
    assert.ok(files.length > 0, `${packId} has no playable files`);
  }

  assert.ok(readdirSync(soundsRoot).length >= packIds.size);
});
