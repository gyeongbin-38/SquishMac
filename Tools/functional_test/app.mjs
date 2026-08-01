import {
  MATERIAL_PROFILES,
  SOUND_TITLES,
  SoundKind,
  TrackpadGestureEngine,
  TrackpadMode,
  TrackpadSessionRecorder,
  audioResponse,
  getProfile,
  planSecondarySound,
} from "./engine.mjs";

const $ = (id) => document.getElementById(id);
const clamp = (value, minimum = 0, maximum = 1) =>
  Math.min(Math.max(Number(value) || 0, minimum), maximum);
const delay = (milliseconds) =>
  new Promise((resolve) => window.setTimeout(resolve, milliseconds));

const GENERIC_LAYERS = Object.freeze({
  [SoundKind.SLIME_KNEAD]: [
    {
      packId: "squishy",
      probability: 0.36,
      volume: [0.1, 0.38],
      rate: [0.68, 0.96],
      delay: [12, 70],
    },
    {
      packId: "bubble",
      probability: 0.22,
      volume: [0.06, 0.22],
      rate: [0.94, 1.24],
      delay: [20, 95],
    },
  ],
  [SoundKind.SLIME_STRETCH]: [
    {
      packId: "squishy",
      probability: 0.42,
      volume: [0.08, 0.3],
      rate: [0.62, 0.9],
      delay: [25, 110],
    },
  ],
  [SoundKind.SLIME_BUBBLE]: [
    {
      packId: "slime",
      probability: 0.7,
      volume: [0.12, 0.42],
      rate: [0.62, 0.88],
      delay: [8, 55],
    },
    {
      packId: "pop",
      probability: 0.38,
      volume: [0.1, 0.34],
      rate: [0.9, 1.18],
      delay: [25, 120],
    },
  ],
  [SoundKind.SLIME_STRETCH_FAILURE]: [
    {
      packId: "squishy",
      probability: 0.24,
      volume: [0.08, 0.24],
      rate: [0.72, 0.94],
      delay: [10, 45],
    },
  ],
  [SoundKind.SLIME_RELEASE]: [
    {
      packId: "bubble",
      probability: 0.48,
      volume: [0.08, 0.32],
      rate: [0.94, 1.28],
      delay: [8, 80],
    },
  ],
  [SoundKind.WAX_PRESS]: [
    {
      packId: "wax",
      probability: 0.24,
      volume: [0.05, 0.2],
      rate: [0.72, 0.98],
      delay: [18, 75],
    },
  ],
  [SoundKind.WAX_CRACK]: [
    {
      packId: "pop",
      probability: 0.46,
      volume: [0.1, 0.34],
      rate: [1.02, 1.34],
      delay: [3, 45],
    },
  ],
  [SoundKind.WAX_CRUSH]: [
    {
      packId: "squishy",
      probability: 0.62,
      volume: [0.16, 0.52],
      rate: [0.62, 0.94],
      delay: [8, 65],
    },
    {
      packId: "bubble",
      probability: 0.44,
      volume: [0.1, 0.36],
      rate: [1, 1.36],
      delay: [15, 105],
    },
  ],
});

const SCENARIOS = Object.freeze([
  {
    id: "slime-knead",
    title: "Standard slime knead",
    mode: TrackpadMode.SLIME,
    profileId: "clear",
    steps: [
      {
        offset: 0,
        fingerCount: 6,
        pressure: 0.45,
        movement: 0.08,
        spread: 0.8,
      },
    ],
  },
  {
    id: "slime-stretch-release",
    title: "Slime stretch and release",
    mode: TrackpadMode.SLIME,
    profileId: "clear",
    steps: [
      {
        offset: 0,
        fingerCount: 5,
        pressure: 0.42,
        movement: 0.32,
        spread: 0.7,
      },
      {
        offset: 0.5,
        fingerCount: 0,
        pressure: 0,
        movement: 0,
        spread: 0,
      },
    ],
  },
  {
    id: "bar-pung",
    title: "Video 3 bar-pung",
    mode: TrackpadMode.SLIME,
    profileId: "clear-video-3",
    steps: [
      {
        offset: 0,
        fingerCount: 6,
        pressure: 0.34,
        movement: 0.08,
        spread: 0.72,
      },
      {
        offset: 0.35,
        fingerCount: 6,
        pressure: 0.52,
        movement: 0.18,
        spread: 0.48,
      },
    ],
  },
  {
    id: "doctor-failure-reset",
    title: "Doctor Putty failure and reset",
    mode: TrackpadMode.SLIME,
    profileId: "doctor-putty-pink",
    steps: [
      {
        offset: 0,
        fingerCount: 6,
        pressure: 0.42,
        movement: 0.82,
        spread: 0.75,
      },
      {
        offset: 1,
        fingerCount: 6,
        pressure: 0.4,
        movement: 0.9,
        spread: 0.8,
      },
      {
        offset: 1.2,
        fingerCount: 6,
        pressure: 0.35,
        movement: 0.2,
        spread: 0.72,
      },
      {
        offset: 2,
        fingerCount: 6,
        pressure: 0.42,
        movement: 0.84,
        spread: 0.82,
      },
    ],
  },
  {
    id: "pastel-wax-stages",
    title: "Video 4 wax press, cracks, crush",
    mode: TrackpadMode.WAX,
    profileId: "pastel-wax-shell-video-4",
    steps: [
      {
        offset: 0,
        fingerCount: 2,
        pressure: 0.24,
        movement: 0.02,
        spread: 0.5,
      },
      {
        offset: 0.3,
        fingerCount: 2,
        pressure: 0.48,
        movement: 0.1,
        spread: 0.43,
      },
      {
        offset: 0.6,
        fingerCount: 2,
        pressure: 0.6,
        movement: 0.08,
        spread: 0.39,
      },
      {
        offset: 0.9,
        fingerCount: 2,
        pressure: 0.82,
        movement: 0.12,
        spread: 0.25,
      },
    ],
  },
  {
    id: "video-9-layer",
    title: "Video 9 pressure-aware texture layer",
    mode: TrackpadMode.SLIME,
    profileId: "white-poke-putty-video-9",
    steps: [
      {
        offset: 0,
        fingerCount: 2,
        pressure: 0.72,
        movement: 0.04,
        spread: 0.18,
      },
    ],
  },
]);

class BrowserSoundPlayer {
  constructor() {
    this.packs = {};
    this.bags = new Map();
    this.lastUrl = new Map();
    this.activeAudio = new Set();
    this.generation = 0;
  }

  async load() {
    const response = await fetch("/api/sound-packs");
    if (!response.ok) throw new Error(`Sound manifest failed: ${response.status}`);
    const payload = await response.json();
    this.packs = payload.packs ?? {};
    return Object.values(this.packs).reduce(
      (sum, items) => sum + items.length,
      0,
    );
  }

  nextUrl(packId, key = packId) {
    const urls = this.packs[packId] ?? [];
    if (urls.length === 0) return null;

    let bag = this.bags.get(key) ?? [];
    if (bag.length === 0) {
      bag = [...urls];
      for (let index = bag.length - 1; index > 0; index -= 1) {
        const swapIndex = Math.floor(Math.random() * (index + 1));
        [bag[index], bag[swapIndex]] = [bag[swapIndex], bag[index]];
      }
      const previous = this.lastUrl.get(key);
      if (bag.length > 1 && bag[bag.length - 1] === previous) {
        const replacement = bag.findIndex((url) => url !== previous);
        [bag[replacement], bag[bag.length - 1]] = [
          bag[bag.length - 1],
          bag[replacement],
        ];
      }
    }

    const selected = bag.pop();
    this.bags.set(key, bag);
    this.lastUrl.set(key, selected);
    return selected;
  }

  playUrl(url, volume, rate) {
    if (!url || volume <= 0.001) return false;
    while (this.activeAudio.size >= 10) {
      const oldest = this.activeAudio.values().next().value;
      oldest.pause();
      this.activeAudio.delete(oldest);
    }
    const audio = new Audio(url);
    audio.volume = clamp(volume);
    audio.playbackRate = clamp(rate, 0.5, 1.5);
    this.activeAudio.add(audio);
    const release = () => this.activeAudio.delete(audio);
    audio.addEventListener("ended", release, { once: true });
    audio.addEventListener("error", release, { once: true });
    audio.play().catch((error) => {
      release();
      setStatus(`Audio blocked: ${error.message}`, true);
    });
    return true;
  }

  play(trigger, masterVolume) {
    if (!$("soundEnabled").checked) return;
    const generation = this.generation;
    const effectiveMaster = clamp(masterVolume) * trigger.volumeScale;
    const response = audioResponse(
      trigger.kind,
      trigger.intensity,
      effectiveMaster,
    );
    const usesReferencePack = Boolean(trigger.soundPackIdOverride);
    const primaryPack = trigger.soundPackIdOverride ?? response.packId;
    const baseRate = usesReferencePack
      ? 0.96 + clamp(trigger.intensity) * 0.06
      : response.rate;
    const variation = usesReferencePack ? 0.012 : 0.025;
    const primaryUrl = this.nextUrl(primaryPack);
    const didPlay = this.playUrl(
      primaryUrl,
      response.volume,
      baseRate + (Math.random() * 2 - 1) * variation,
    );
    if (!didPlay) {
      setStatus(`No audio files in pack: ${primaryPack}`, true);
      return;
    }

    const explicitPlan = planSecondarySound(
      trigger.secondarySoundLayer,
      trigger.intensity,
    );
    if (explicitPlan) {
      window.setTimeout(() => {
        if (generation !== this.generation) return;
        this.playUrl(
          this.nextUrl(
            explicitPlan.soundPackId,
            `${explicitPlan.soundPackId}:material-layer`,
          ),
          response.volume * explicitPlan.volumeScale,
          baseRate +
            explicitPlan.rateOffset +
            (Math.random() * 2 - 1) * 0.012,
        );
      }, explicitPlan.delayMilliseconds);
      return;
    }

    if (usesReferencePack) return;
    for (const layer of GENERIC_LAYERS[trigger.kind] ?? []) {
      const probability =
        layer.probability * (0.62 + clamp(trigger.intensity) * 0.38);
      if (Math.random() > probability) continue;
      const progress = clamp(trigger.intensity);
      const volume =
        layer.volume[0] + (layer.volume[1] - layer.volume[0]) * progress;
      const rate = layer.rate[0] + (layer.rate[1] - layer.rate[0]) * progress;
      const layerDelay =
        layer.delay[0] +
        (layer.delay[1] - layer.delay[0]) * Math.random();
      window.setTimeout(() => {
        if (generation !== this.generation) return;
        this.playUrl(
          this.nextUrl(layer.packId, `${layer.packId}:${trigger.kind}`),
          volume * effectiveMaster,
          rate + (Math.random() * 2 - 1) * 0.025,
        );
      }, layerDelay);
    }
  }

  stopAll() {
    this.generation += 1;
    for (const audio of this.activeAudio) {
      audio.pause();
      audio.currentTime = 0;
    }
    this.activeAudio.clear();
  }
}

const engine = new TrackpadGestureEngine();
const recorder = new TrackpadSessionRecorder();
const soundPlayer = new BrowserSoundPlayer();
let currentCenter = { x: 0.5, y: 0.5 };
let pointerActive = false;
let lastPointer = null;
let gestureCount = 0;
let eventRows = [];

const currentMode = () => $("mode").value;
const currentProfile = () => getProfile($("material").value);
const currentTuning = () => ({
  response: Number($("response").value),
  soundDensity: Number($("soundDensity").value),
});

function setStatus(message, isError = false) {
  $("status").textContent = message;
  $("status").classList.toggle("error", isError);
}

function setRange(id, value) {
  $(id).value = String(value);
  updateRangeOutput(id);
}

function updateRangeOutput(id) {
  const output = $(`${id}Value`);
  if (!output) return;
  const value = Number($(id).value);
  output.value = id === "fingerCount" ? String(value) : value.toFixed(2);
}

function populateProfiles(mode, preferredId = null) {
  const available = MATERIAL_PROFILES.filter((item) => item.mode === mode);
  const fallbackId =
    mode === TrackpadMode.WAX
      ? "pastel-wax-shell-video-4"
      : "doctor-putty-pink";
  $("material").replaceChildren(
    ...available.map((item) => {
      const option = document.createElement("option");
      option.value = item.id;
      option.textContent = item.displayName;
      return option;
    }),
  );
  const requested = available.some((item) => item.id === preferredId)
    ? preferredId
    : fallbackId;
  $("material").value = available.some((item) => item.id === requested)
    ? requested
    : available[0].id;
  applyProfileDefaults();
}

function applyProfileDefaults() {
  const selected = currentProfile();
  setRange("response", selected.tuning.response);
  setRange("soundDensity", selected.tuning.soundDensity);
  $("profileSummary").textContent = selected.rules.interactionSummary;
  resetEngine("Profile loaded");
}

function generatedTouches(fingerCount, spread) {
  if (fingerCount <= 0) return [];
  const radius = clamp(spread) * 0.35;
  return Array.from({ length: fingerCount }, (_, index) => {
    const angle = (Math.PI * 2 * index) / fingerCount;
    return {
      id: `simulated-${index + 1}`,
      x: clamp(currentCenter.x + Math.cos(angle) * radius),
      y: clamp(currentCenter.y + Math.sin(angle) * radius),
    };
  });
}

function forceStage(pressure) {
  if (pressure <= 0.01) return 0;
  return pressure >= 0.75 ? 2 : 1;
}

function readFrame() {
  return {
    fingerCount: Number($("fingerCount").value),
    pressure: Number($("pressure").value),
    movement: Number($("movement").value),
    spread: Number($("spread").value),
  };
}

function applyFrame(frame) {
  setRange("fingerCount", frame.fingerCount);
  setRange("pressure", frame.pressure);
  setRange("movement", frame.movement);
  setRange("spread", frame.spread);
}

function evaluateFrame({
  timestamp = performance.now() / 1000,
  at = new Date(),
  frame = readFrame(),
} = {}) {
  const profile = currentProfile();
  const result = engine.evaluate({
    mode: currentMode(),
    ...frame,
    timestamp,
    tuning: currentTuning(),
    interactionRules: profile.rules,
  });

  $("liveIntensity").textContent = result.liveIntensity.toFixed(3);
  $("intensityMeter").value = result.liveIntensity;
  $("barPungState").textContent = engine.isBarPungPrepared ? "armed" : "idle";

  if (result.trigger) {
    gestureCount += 1;
    $("lastGesture").textContent =
      `${result.trigger.label} (${result.trigger.kind})`;
    $("lastPack").textContent =
      result.trigger.soundPackIdOverride ?? "generic recipe";
    soundPlayer.play(result.trigger, Number($("masterVolume").value));
    appendEventRow(result.trigger, timestamp);
  }
  $("gestureCount").textContent = String(gestureCount);

  recorder.append({
    mode: currentMode(),
    ...frame,
    forceStage: forceStage(frame.pressure),
    intensity: result.liveIntensity,
    touches: generatedTouches(frame.fingerCount, frame.spread),
    trigger: result.trigger,
    at,
  });
  updateRecordingUi();
  renderTouchPoints(frame.fingerCount, frame.spread);
  return result;
}

function appendEventRow(trigger, timestamp) {
  eventRows.unshift({
    time: timestamp,
    label: trigger.label,
    kind: trigger.kind,
    pack: trigger.soundPackIdOverride ?? "generic",
    intensity: trigger.intensity,
  });
  eventRows = eventRows.slice(0, 20);
  $("eventLog").replaceChildren(
    ...eventRows.map((item) => {
      const row = document.createElement("tr");
      for (const value of [
        item.time.toFixed(3),
        item.kind,
        item.pack,
        item.intensity.toFixed(3),
      ]) {
        const cell = document.createElement("td");
        cell.textContent = value;
        row.append(cell);
      }
      return row;
    }),
  );
}

function resetEngine(status = "Engine reset") {
  engine.reset();
  soundPlayer.stopAll();
  gestureCount = 0;
  eventRows = [];
  $("gestureCount").textContent = "0";
  $("lastGesture").textContent = "None";
  $("lastPack").textContent = "-";
  $("liveIntensity").textContent = "0.000";
  $("intensityMeter").value = 0;
  $("barPungState").textContent = "idle";
  $("eventLog").replaceChildren();
  setStatus(status);
}

function renderTouchPoints(fingerCount, spread) {
  const points = generatedTouches(fingerCount, spread);
  $("touchPoints").replaceChildren(
    ...points.map((point) => {
      const dot = document.createElement("span");
      dot.className = "touch-point";
      dot.style.left = `${point.x * 100}%`;
      dot.style.top = `${(1 - point.y) * 100}%`;
      return dot;
    }),
  );
}

function updateRecordingUi() {
  $("recordingState").textContent = recorder.isRecording
    ? `recording (${recorder.samples.length})`
    : recorder.hasRecording
      ? `stopped (${recorder.samples.length})`
      : "empty";
  $("startRecording").disabled = recorder.isRecording;
  $("stopRecording").disabled = !recorder.isRecording;
  $("exportRecording").disabled = !recorder.hasRecording;
  for (const id of [
    "mode",
    "material",
    "scenario",
    "response",
    "soundDensity",
  ]) {
    $(id).disabled = recorder.isRecording;
  }
}

function prepareSelectedScenario() {
  const scenario = SCENARIOS.find((item) => item.id === $("scenario").value);
  if (!scenario || recorder.isRecording) return;
  $("mode").value = scenario.mode;
  populateProfiles(scenario.mode, scenario.profileId);
}

async function runScenario() {
  const scenario = SCENARIOS.find((item) => item.id === $("scenario").value);
  if (!scenario) return;
  const scenarioNeedsConfiguration =
    currentMode() !== scenario.mode ||
    currentProfile().id !== scenario.profileId;
  if (scenarioNeedsConfiguration && recorder.isRecording) {
    setStatus("Stop recording before changing the scenario configuration", true);
    return;
  }
  $("runScenario").disabled = true;
  if (scenarioNeedsConfiguration) {
    $("mode").value = scenario.mode;
    populateProfiles(scenario.mode, scenario.profileId);
  }
  resetEngine(`Running: ${scenario.title}`);
  const startTimestamp = performance.now() / 1000;
  let previousOffset = 0;

  try {
    for (const step of scenario.steps) {
      const waitTime = Math.max(80, (step.offset - previousOffset) * 1000);
      await delay(waitTime);
      applyFrame(step);
      evaluateFrame({
        timestamp: startTimestamp + step.offset,
        at: new Date(),
        frame: step,
      });
      previousOffset = step.offset;
    }
    setStatus(`Scenario complete: ${scenario.title}`);
  } finally {
    $("runScenario").disabled = false;
  }
}

function exportRecording() {
  const encoded = recorder.encodedSession({
    osVersion: navigator.userAgent,
    architecture: "browser",
  });
  const blob = new Blob([encoded], { type: "application/json" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = `squishmac-functional-${new Date()
    .toISOString()
    .replaceAll(":", "-")}.json`;
  link.click();
  URL.revokeObjectURL(link.href);
}

function configurePointerSurface() {
  const surface = $("touchSurface");
  surface.addEventListener("pointerdown", (event) => {
    pointerActive = true;
    surface.setPointerCapture(event.pointerId);
    lastPointer = { x: event.clientX, y: event.clientY };
    const frame = readFrame();
    if (frame.fingerCount === 0) {
      setRange(
        "fingerCount",
        currentMode() === TrackpadMode.WAX
          ? 2
          : currentProfile().rules.minimumFingerCount,
      );
    }
    if (frame.pressure < 0.18) setRange("pressure", 0.35);
    updatePointerCenter(event, surface);
    evaluateFrame();
  });

  surface.addEventListener("pointermove", (event) => {
    if (!pointerActive || !lastPointer) return;
    const rectangle = surface.getBoundingClientRect();
    const distance = Math.hypot(
      event.clientX - lastPointer.x,
      event.clientY - lastPointer.y,
    );
    setRange(
      "movement",
      clamp((distance / Math.hypot(rectangle.width, rectangle.height)) * 8),
    );
    lastPointer = { x: event.clientX, y: event.clientY };
    updatePointerCenter(event, surface);
    evaluateFrame();
  });

  const release = (event) => {
    if (!pointerActive) return;
    pointerActive = false;
    lastPointer = null;
    if (surface.hasPointerCapture(event.pointerId)) {
      surface.releasePointerCapture(event.pointerId);
    }
    setRange("fingerCount", 0);
    setRange("pressure", 0);
    setRange("movement", 0);
    evaluateFrame();
  };
  surface.addEventListener("pointerup", release);
  surface.addEventListener("pointercancel", release);
  surface.addEventListener(
    "wheel",
    (event) => {
      event.preventDefault();
      const direction = event.deltaY < 0 ? 0.05 : -0.05;
      setRange("pressure", clamp(Number($("pressure").value) + direction));
      evaluateFrame();
    },
    { passive: false },
  );
}

function updatePointerCenter(event, surface) {
  const rectangle = surface.getBoundingClientRect();
  currentCenter = {
    x: clamp((event.clientX - rectangle.left) / rectangle.width),
    y: clamp(1 - (event.clientY - rectangle.top) / rectangle.height),
  };
  renderTouchPoints(
    Number($("fingerCount").value),
    Number($("spread").value),
  );
}

async function initialize() {
  for (const scenario of SCENARIOS) {
    const option = document.createElement("option");
    option.value = scenario.id;
    option.textContent = scenario.title;
    $("scenario").append(option);
  }

  populateProfiles(TrackpadMode.SLIME, "doctor-putty-pink");
  prepareSelectedScenario();
  for (const id of [
    "fingerCount",
    "pressure",
    "movement",
    "spread",
    "response",
    "soundDensity",
    "masterVolume",
  ]) {
    updateRangeOutput(id);
    $(id).addEventListener("input", () => {
      updateRangeOutput(id);
      if (["fingerCount", "pressure", "movement", "spread"].includes(id)) {
        renderTouchPoints(
          Number($("fingerCount").value),
          Number($("spread").value),
        );
      }
    });
  }

  $("mode").addEventListener("change", () => {
    populateProfiles(currentMode());
  });
  $("material").addEventListener("change", applyProfileDefaults);
  $("scenario").addEventListener("change", prepareSelectedScenario);
  $("evaluate").addEventListener("click", () => evaluateFrame());
  $("resetEngine").addEventListener("click", () => resetEngine());
  $("runScenario").addEventListener("click", runScenario);
  $("startRecording").addEventListener("click", () => {
    recorder.start({
      tuning: currentTuning(),
      materialProfileId: currentProfile().id,
    });
    updateRecordingUi();
    setStatus("Recording started");
  });
  $("stopRecording").addEventListener("click", () => {
    recorder.stop();
    updateRecordingUi();
    setStatus("Recording stopped");
  });
  $("clearRecording").addEventListener("click", () => {
    recorder.clear();
    updateRecordingUi();
    setStatus("Recording cleared");
  });
  $("exportRecording").addEventListener("click", exportRecording);
  $("stopAudio").addEventListener("click", () => soundPlayer.stopAll());
  configurePointerSurface();
  updateRecordingUi();
  renderTouchPoints(0, Number($("spread").value));

  try {
    const count = await soundPlayer.load();
    setStatus(`Ready: ${count} bundled sounds loaded`);
  } catch (error) {
    setStatus(error.message, true);
  }
}

initialize();
