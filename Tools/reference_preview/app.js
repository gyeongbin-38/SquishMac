"use strict";

const params = new URLSearchParams(window.location.search);
const datasetRoot = normalizeRoot(params.get("dataset") || "/AnalysisOutput/1");

const labels = {
  wax_press: "왁스 누르기",
  wax_crack: "왁스 깨짐",
  wax_crush: "왁스 부수기",
  slime_knead: "슬라임 주무르기",
  slime_stretch: "슬라임 늘리기",
  slime_release: "슬라임 놓기",
  brittle_crack: "단단한 깨짐",
  clay_snap: "클레이 스냅",
  wax_fine_crack: "왁스 미세 균열",
  wax_shell_crush: "왁스 셸 파손",
  suction_pop: "흡착 팝",
  wet_friction: "젖은 마찰",
  micro_crackle: "미세 크랙",
  soft_crackle: "부드러운 크래클",
  putty_soft_crackle: "퍼티 부드러운 크래클",
  stretch_too_fast_failure: "과속 늘리기 실패",
  slime_snap: "슬라임 스냅",
  micro_pop: "미세 팝",
  bubble_cluster: "버블 연속음",
  dense_squish: "묵직한 스퀴시",
};

const elements = {};
const state = {
  dataset: null,
  motion: [],
  gestures: [],
  audioEvents: [],
  duration: 0,
  lastPlaybackTime: 0,
  playedEventIds: new Set(),
  activeAudio: new Set(),
  audioBufferCache: new Map(),
  audioContext: null,
  chartFrame: null,
};

document.addEventListener("DOMContentLoaded", initialize);

async function initialize() {
  cacheElements();
  bindStaticControls();

  try {
    const dataset = await fetchJSON(resolvePath("dataset.json"));
    const [motion, gestures, audioEvents] = await Promise.all([
      fetchJSON(resolvePath(dataset.artifacts.motion_frames)),
      fetchJSON(resolvePath(dataset.artifacts.gesture_timeline)),
      fetchJSON(resolvePath(dataset.artifacts.audio_events)),
    ]);

    state.dataset = dataset;
    state.motion = motion;
    state.gestures = gestures;
    state.audioEvents = audioEvents;
    state.duration = dataset.video.duration || dataset.source.duration || 0;

    populateSummary();
    configureVideo();
    populateAudioFilter();
    renderClipList();
    renderTimelineMarkers();
    elements.labContent.hidden = false;
    resizeAndDrawChart();
    updateAtTime(0);

    setStatus("분석 데이터 준비됨", "ready");
  } catch (error) {
    showError(error);
  }
}

function cacheElements() {
  [
    "loadStatus",
    "materialName",
    "materialDescription",
    "durationStat",
    "coverageStat",
    "gestureStat",
    "audioStat",
    "errorPanel",
    "errorMessage",
    "labContent",
    "trackingVideo",
    "timeDisplay",
    "cornerGesture",
    "cornerPressure",
    "sourceAudioToggle",
    "mappedAudioToggle",
    "playbackRate",
    "mappedVolume",
    "mappedVolumeValue",
    "motionChart",
    "eventTimeline",
    "gestureMarkers",
    "audioMarkers",
    "timelinePlayhead",
    "currentTimestamp",
    "currentGesture",
    "gestureIntensity",
    "handCount",
    "fingertipCount",
    "movementValue",
    "movementMeter",
    "pressureValue",
    "pressureMeter",
    "spreadValue",
    "spreadMeter",
    "audioFilter",
    "audioClipList",
    "clipTemplate",
  ].forEach((id) => {
    elements[id] = document.getElementById(id);
  });
}

function bindStaticControls() {
  elements.sourceAudioToggle.addEventListener("change", () => {
    elements.trackingVideo.muted = !elements.sourceAudioToggle.checked;
  });

  elements.mappedAudioToggle.addEventListener("change", () => {
    if (!elements.mappedAudioToggle.checked) {
      stopAllMappedAudio();
    }
  });

  elements.playbackRate.addEventListener("change", () => {
    elements.trackingVideo.playbackRate = Number(elements.playbackRate.value);
  });

  elements.mappedVolume.addEventListener("input", () => {
    elements.mappedVolumeValue.value = `${elements.mappedVolume.value}%`;
    updateActiveAudioVolumes();
  });

  elements.audioFilter.addEventListener("change", renderClipList);
  elements.motionChart.addEventListener("pointerdown", seekFromChart);

  window.addEventListener("resize", () => {
    window.cancelAnimationFrame(state.chartFrame);
    state.chartFrame = window.requestAnimationFrame(resizeAndDrawChart);
  });
}

function populateSummary() {
  const { dataset } = state;
  const material = dataset.material_profile || {};
  const summary = dataset.summary || {};
  const interactionRules = material.interaction_rules || {};
  const textureDescription = [
    material.outer_texture,
    material.core_texture,
  ].filter(Boolean).join(" + ") || material.notes || "재질 설명 없음";
  const failureThreshold = interactionRules.fast_stretch_failure_movement_threshold;

  elements.materialName.textContent = material.display_name || material.id || "분류 미정";
  elements.materialDescription.textContent = failureThreshold == null
    ? textureDescription
    : `${textureDescription} · 과속 늘리기 실패 기준 ${Math.round(failureThreshold * 100)}%`;
  const cameraTuning = dataset.input_tuning?.camera;
  const trackpadTuning = dataset.input_tuning?.trackpad;
  if (cameraTuning && trackpadTuning) {
    const isWax = material.category === "wax_shell";
    const tuningDetails = isWax
      ? [
        ["Camera crack", cameraTuning.crack_pressure_threshold],
        ["Camera crush", cameraTuning.crush_pressure_threshold],
        ["Trackpad crack", trackpadTuning.crack_pressure_threshold],
        ["Trackpad crush", trackpadTuning.crush_pressure_threshold],
      ]
      : [
        ["Camera stretch", cameraTuning.stretch_movement_threshold],
        ["Trackpad stretch", trackpadTuning.stretch_movement_threshold],
      ];
    const availableDetails = tuningDetails
      .filter(([, value]) => Number.isFinite(value))
      .map(([label, value]) => `${label} ${Math.round(value * 100)}%`);
    if (availableDetails.length > 0) {
      elements.materialDescription.textContent += ` / ${availableDetails.join(" / ")}`;
    }
  }
  elements.durationStat.textContent = formatClock(state.duration);
  elements.coverageStat.textContent = formatPercent(summary.hand_detection_coverage || 0);
  elements.gestureStat.textContent = `${summary.gesture_event_count || state.gestures.length}개`;
  elements.audioStat.textContent = `${summary.audio_event_count || state.audioEvents.length}개`;
}

function configureVideo() {
  elements.trackingVideo.src = resolvePath(state.dataset.artifacts.tracking_video);
  elements.trackingVideo.poster = resolvePath(
    state.dataset.artifacts.tracking_poster || "overlays/poster.jpg",
  );
  elements.trackingVideo.muted = true;
  elements.trackingVideo.playbackRate = Number(elements.playbackRate.value);

  elements.trackingVideo.addEventListener("loadedmetadata", () => {
    if (Number.isFinite(elements.trackingVideo.duration)) {
      state.duration = elements.trackingVideo.duration;
      elements.durationStat.textContent = formatClock(state.duration);
    }
    updateAtTime(elements.trackingVideo.currentTime);
  });

  elements.trackingVideo.addEventListener("timeupdate", () => {
    const time = elements.trackingVideo.currentTime;
    playCrossedAudioEvents(state.lastPlaybackTime, time);
    updateAtTime(time);
    state.lastPlaybackTime = time;
  });

  elements.trackingVideo.addEventListener("seeking", () => {
    stopAllMappedAudio();
    preparePlayedEvents(elements.trackingVideo.currentTime);
    state.lastPlaybackTime = elements.trackingVideo.currentTime;
    updateAtTime(elements.trackingVideo.currentTime);
  });

  elements.trackingVideo.addEventListener("play", () => {
    state.lastPlaybackTime = elements.trackingVideo.currentTime;
  });

  elements.trackingVideo.addEventListener("ended", () => {
    stopAllMappedAudio();
    state.playedEventIds.clear();
    state.lastPlaybackTime = 0;
  });
}

function populateAudioFilter() {
  const textures = [...new Set(state.audioEvents.map((event) => event.suggested_texture))].sort();
  textures.forEach((texture) => {
    const option = document.createElement("option");
    option.value = texture;
    option.textContent = labels[texture] || texture;
    elements.audioFilter.appendChild(option);
  });
}

function renderClipList() {
  const filter = elements.audioFilter.value;
  const events = filter === "all"
    ? state.audioEvents
    : state.audioEvents.filter((event) => event.suggested_texture === filter);

  elements.audioClipList.replaceChildren();

  if (events.length === 0) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent = "이 필터에 해당하는 사운드가 없습니다.";
    elements.audioClipList.appendChild(empty);
    return;
  }

  events.forEach((event) => {
    const fragment = elements.clipTemplate.content.cloneNode(true);
    const row = fragment.querySelector(".clip-row");
    const playButton = fragment.querySelector(".clip-play");
    const seekButton = fragment.querySelector(".clip-seek");
    const texture = fragment.querySelector(".clip-texture");
    const meta = fragment.querySelector(".clip-meta");

    texture.textContent = labels[event.suggested_texture] || event.suggested_texture;
    meta.textContent = `${formatTimestamp(event.timestamp)} · ${labels[event.gesture_kind] || event.gesture_kind} · ${formatGain(event)}`;

    playButton.addEventListener("click", () => playMappedClip(event, row));
    seekButton.addEventListener("click", () => seekTo(event.timestamp, true));
    elements.audioClipList.appendChild(fragment);
  });
}

function renderTimelineMarkers() {
  elements.gestureMarkers.replaceChildren();
  elements.audioMarkers.replaceChildren();

  state.gestures.forEach((event) => {
    elements.gestureMarkers.appendChild(createMarker(event, false));
  });

  state.audioEvents.forEach((event) => {
    elements.audioMarkers.appendChild(createMarker(event, true));
  });
}

function createMarker(event, isAudio) {
  const marker = document.createElement("button");
  const name = isAudio
    ? labels[event.suggested_texture] || event.suggested_texture
    : labels[event.kind] || event.kind;
  marker.type = "button";
  marker.className = `event-marker${isAudio ? " audio" : ""}`;
  marker.style.left = `${timeRatio(event.timestamp) * 100}%`;
  marker.title = `${formatTimestamp(event.timestamp)} ${name}`;
  marker.setAttribute("aria-label", marker.title);
  marker.addEventListener("click", () => {
    seekTo(event.timestamp, false);
    if (isAudio) {
      playMappedClip(event);
    }
  });
  return marker;
}

function updateAtTime(time) {
  const frame = findNearestByTimestamp(state.motion, time);
  const gesture = findCurrentGesture(time);
  const ratio = timeRatio(time);

  elements.timeDisplay.textContent = `${formatTimestamp(time)} / ${formatTimestamp(state.duration)}`;
  elements.currentTimestamp.textContent = `${time.toFixed(3)}s`;
  elements.timelinePlayhead.style.left = `calc(44px + (100% - 44px) * ${ratio})`;

  if (!frame) {
    return;
  }

  const movement = clamp(frame.movement || 0);
  const pressure = clamp(frame.pressure_estimate || 0);
  const spread = clamp(frame.spread || 0);
  const gestureName = gesture ? labels[gesture.kind] || gesture.kind : "이벤트 사이";

  elements.handCount.textContent = frame.hand_count ?? 0;
  elements.fingertipCount.textContent = frame.fingertip_count ?? 0;
  setMeter(elements.movementMeter, elements.movementValue, movement);
  setMeter(elements.pressureMeter, elements.pressureValue, pressure);
  setMeter(elements.spreadMeter, elements.spreadValue, spread);

  elements.currentGesture.textContent = gestureName;
  elements.cornerGesture.textContent = gestureName;
  elements.cornerPressure.textContent = `압력 추정 ${Math.round(pressure * 100)}%`;
  elements.gestureIntensity.textContent = gesture
    ? `강도 ${Math.round(clamp(gesture.intensity || 0) * 100)}% · ${formatTimestamp(gesture.timestamp)}`
    : "±0.8초 안에 동작 이벤트 없음";

  drawChart(ratio);
}

function findCurrentGesture(time) {
  if (state.gestures.length === 0) {
    return null;
  }

  const nearest = findNearestByTimestamp(state.gestures, time);
  return nearest && Math.abs(nearest.timestamp - time) <= 0.8 ? nearest : null;
}

function playCrossedAudioEvents(previousTime, currentTime) {
  if (!elements.mappedAudioToggle.checked || elements.trackingVideo.paused) {
    return;
  }

  if (currentTime < previousTime || currentTime - previousTime > 1.2) {
    preparePlayedEvents(currentTime);
    return;
  }

  state.audioEvents.forEach((event) => {
    const crossed = event.timestamp > previousTime && event.timestamp <= currentTime + 0.06;
    if (crossed && !state.playedEventIds.has(event.id)) {
      state.playedEventIds.add(event.id);
      playMappedClip(event);
    }
  });
}

async function playMappedClip(event, row = null) {
  try {
    const context = ensureAudioContext();
    if (context.state === "suspended") {
      await context.resume();
    }
    const buffer = await loadAudioBuffer(event);
    const source = context.createBufferSource();
    const gain = context.createGain();
    const playback = { source, gain, event, row };

    source.buffer = buffer;
    source.playbackRate.value = elements.trackingVideo.playbackRate || 1;
    gain.gain.value = mappedGainFor(event);
    source.connect(gain);
    gain.connect(context.destination);
    state.activeAudio.add(playback);

    if (row) {
      row.classList.add("playing");
    }

    source.addEventListener("ended", () => {
      state.activeAudio.delete(playback);
      if (row) {
        row.classList.remove("playing");
      }
    }, { once: true });
    source.start();
  } catch (error) {
    console.error("Mapped clip playback failed.", error);
    if (row) {
      row.classList.remove("playing");
    }
  }
}

function updateActiveAudioVolumes() {
  if (!state.audioContext) {
    return;
  }
  state.activeAudio.forEach((playback) => {
    playback.gain.gain.setTargetAtTime(
      mappedGainFor(playback.event),
      state.audioContext.currentTime,
      0.01,
    );
  });
}

function stopAllMappedAudio() {
  state.activeAudio.forEach((playback) => {
    try {
      playback.source.stop();
    } catch {
      // A source may already have ended between the event and this cleanup.
    }
  });
  state.activeAudio.clear();
  document.querySelectorAll(".clip-row.playing").forEach((row) => row.classList.remove("playing"));
}

function preparePlayedEvents(time) {
  state.playedEventIds = new Set(
    state.audioEvents.filter((event) => event.timestamp <= time).map((event) => event.id),
  );
}

function eventGain(event) {
  const peaks = state.audioEvents.map((item) => item.peak || 0);
  const minimum = Math.min(...peaks);
  const maximum = Math.max(...peaks);
  if (maximum <= minimum) {
    return 0.7;
  }
  return 0.3 + 0.7 * clamp(((event.peak || minimum) - minimum) / (maximum - minimum));
}

function mappedGainFor(event) {
  const master = Number(elements.mappedVolume.value) / 100;
  const targetPeak = (0.28 + 0.42 * eventGain(event)) * master;
  const recordedPeak = Math.max(0.001, Number(event.peak) || 0.001);
  return Math.min(24, targetPeak / recordedPeak);
}

function formatGain(event) {
  return `재생 세기 ${Math.round(eventGain(event) * 100)}%`;
}

function ensureAudioContext() {
  if (!state.audioContext) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) {
      throw new Error("이 브라우저는 Web Audio를 지원하지 않습니다.");
    }
    state.audioContext = new AudioContextClass();
  }
  return state.audioContext;
}

async function loadAudioBuffer(event) {
  const path = resolvePath(event.clip_path);
  if (!state.audioBufferCache.has(path)) {
    const promise = fetch(path)
      .then((response) => {
        if (!response.ok) {
          throw new Error(`${path} 요청 실패 (${response.status})`);
        }
        return response.arrayBuffer();
      })
      .then((data) => ensureAudioContext().decodeAudioData(data));
    state.audioBufferCache.set(path, promise);
  }
  return state.audioBufferCache.get(path);
}

function resizeAndDrawChart() {
  const canvas = elements.motionChart;
  const rect = canvas.getBoundingClientRect();
  const scale = window.devicePixelRatio || 1;
  canvas.width = Math.max(1, Math.round(rect.width * scale));
  canvas.height = Math.max(1, Math.round(rect.height * scale));
  drawChart(timeRatio(elements.trackingVideo.currentTime || 0));
}

function drawChart(playheadRatio = 0) {
  const canvas = elements.motionChart;
  const context = canvas.getContext("2d");
  const scale = window.devicePixelRatio || 1;
  const width = canvas.width / scale;
  const height = canvas.height / scale;

  context.setTransform(scale, 0, 0, scale, 0, 0);
  context.clearRect(0, 0, width, height);
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, width, height);

  context.strokeStyle = "#e3e8e5";
  context.lineWidth = 1;
  [0.25, 0.5, 0.75].forEach((fraction) => {
    const y = Math.round(height * fraction) + 0.5;
    context.beginPath();
    context.moveTo(0, y);
    context.lineTo(width, y);
    context.stroke();
  });

  drawSeries(context, width, height, "movement", "#2b70b7");
  drawSeries(context, width, height, "pressure_estimate", "#db5548");

  const x = clamp(playheadRatio) * width;
  context.strokeStyle = "#17201b";
  context.lineWidth = 2;
  context.beginPath();
  context.moveTo(x, 0);
  context.lineTo(x, height);
  context.stroke();
}

function drawSeries(context, width, height, key, color) {
  if (state.motion.length < 2) {
    return;
  }

  context.beginPath();
  context.strokeStyle = color;
  context.lineWidth = 2;
  context.lineJoin = "round";

  state.motion.forEach((frame, index) => {
    const x = timeRatio(frame.timestamp) * width;
    const y = height - clamp(frame[key] || 0) * (height - 8) - 4;
    if (index === 0) {
      context.moveTo(x, y);
    } else {
      context.lineTo(x, y);
    }
  });
  context.stroke();
}

function seekFromChart(event) {
  const rect = elements.motionChart.getBoundingClientRect();
  const ratio = clamp((event.clientX - rect.left) / rect.width);
  seekTo(ratio * state.duration, false);
}

function seekTo(time, play) {
  elements.trackingVideo.currentTime = Math.max(0, Math.min(time, state.duration));
  updateAtTime(elements.trackingVideo.currentTime);
  if (play) {
    elements.trackingVideo.play().catch(() => {});
  }
}

function findNearestByTimestamp(items, time) {
  if (!items.length) {
    return null;
  }

  let low = 0;
  let high = items.length - 1;
  while (low <= high) {
    const middle = Math.floor((low + high) / 2);
    if (items[middle].timestamp < time) {
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }

  if (low === 0) {
    return items[0];
  }
  if (low >= items.length) {
    return items[items.length - 1];
  }
  return Math.abs(items[low].timestamp - time) < Math.abs(items[low - 1].timestamp - time)
    ? items[low]
    : items[low - 1];
}

function setMeter(meter, output, value) {
  meter.value = value;
  output.value = `${Math.round(value * 100)}%`;
}

function resolvePath(path) {
  if (/^https?:\/\//.test(path)) {
    return path;
  }
  const cleanPath = String(path).replace(/^\.?\//, "");
  return `${datasetRoot}/${cleanPath}`;
}

function normalizeRoot(root) {
  const value = String(root).trim().replace(/\\/g, "/").replace(/\/+$/, "");
  return value.startsWith("/") ? value : `/${value}`;
}

function timeRatio(time) {
  return state.duration > 0 ? clamp(time / state.duration) : 0;
}

function clamp(value, minimum = 0, maximum = 1) {
  return Math.min(maximum, Math.max(minimum, Number(value) || 0));
}

function formatTimestamp(seconds) {
  const safeSeconds = Math.max(0, Number(seconds) || 0);
  const minutes = Math.floor(safeSeconds / 60);
  const remainder = safeSeconds - minutes * 60;
  return `${String(minutes).padStart(2, "0")}:${remainder.toFixed(3).padStart(6, "0")}`;
}

function formatClock(seconds) {
  const safeSeconds = Math.max(0, Number(seconds) || 0);
  const minutes = Math.floor(safeSeconds / 60);
  const remainder = Math.round(safeSeconds - minutes * 60);
  return `${minutes}:${String(remainder).padStart(2, "0")}`;
}

function formatPercent(value) {
  return `${Math.round(clamp(value) * 100)}%`;
}

async function fetchJSON(path) {
  const response = await fetch(path);
  if (!response.ok) {
    throw new Error(`${path} 요청 실패 (${response.status})`);
  }
  return response.json();
}

function setStatus(message, kind) {
  elements.loadStatus.textContent = message;
  elements.loadStatus.className = `status-badge ${kind}`;
}

function showError(error) {
  setStatus("불러오기 실패", "error");
  elements.errorPanel.hidden = false;
  elements.errorMessage.textContent = `${error.message} 서버 실행 위치와 dataset 경로를 확인하세요.`;
}
