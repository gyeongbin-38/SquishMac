#!/usr/bin/env python3
"""Build a per-material SquishMac motion and sound dataset from a local video."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import subprocess
import urllib.request
from dataclasses import dataclass
from itertools import permutations
from pathlib import Path
from typing import Any

import cv2
import mediapipe as mp
import numpy as np
import soundfile as sf
from scipy.signal import butter, find_peaks, istft, sosfiltfilt, stft


HAND_MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/hand_landmarker/"
    "hand_landmarker/float16/1/hand_landmarker.task"
)
JOINT_NAMES = [
    "wrist",
    "thumb_cmc",
    "thumb_mcp",
    "thumb_ip",
    "thumb_tip",
    "index_mcp",
    "index_pip",
    "index_dip",
    "index_tip",
    "middle_mcp",
    "middle_pip",
    "middle_dip",
    "middle_tip",
    "ring_mcp",
    "ring_pip",
    "ring_dip",
    "ring_tip",
    "little_mcp",
    "little_pip",
    "little_dip",
    "little_tip",
]
TIP_INDICES = [4, 8, 12, 16, 20]
HAND_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 4),
    (0, 5), (5, 6), (6, 7), (7, 8),
    (5, 9), (9, 10), (10, 11), (11, 12),
    (9, 13), (13, 14), (14, 15), (15, 16),
    (13, 17), (17, 18), (18, 19), (19, 20), (0, 17),
]


def clamp(value: float, lower: float = 0.0, upper: float = 1.0) -> float:
    return min(max(float(value), lower), upper)


def distance(left: tuple[float, float], right: tuple[float, float]) -> float:
    return math.hypot(left[0] - right[0], left[1] - right[1])


def percentile(values: list[float], amount: float) -> float:
    if not values:
        return 0.0
    return float(np.percentile(np.asarray(values, dtype=np.float64), amount * 100))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def find_ffmpeg(explicit_path: str | None) -> Path:
    if explicit_path:
        candidate = Path(explicit_path)
        if candidate.is_file():
            return candidate
        raise FileNotFoundError(f"FFmpeg was not found at {candidate}")

    executable = shutil.which("ffmpeg")
    if executable:
        return Path(executable)

    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        package_root = Path(local_app_data) / "Microsoft" / "WinGet" / "Packages"
        matches = list(package_root.glob("**/ffmpeg.exe"))
        if matches:
            return matches[0]

    raise FileNotFoundError(
        "FFmpeg is required. Install Gyan.FFmpeg.Essentials or pass --ffmpeg."
    )


def ensure_model(path: Path) -> None:
    if path.is_file() and path.stat().st_size > 1_000_000:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading hand landmark model to {path}")
    urllib.request.urlretrieve(HAND_MODEL_URL, path)


def native_safe_model_path(requested_path: Path) -> Path:
    try:
        str(requested_path).encode("ascii")
        return requested_path
    except UnicodeEncodeError:
        local_app_data = os.environ.get("LOCALAPPDATA")
        if not local_app_data:
            raise RuntimeError(
                "MediaPipe on Windows requires an ASCII-only model path. "
                "Pass --model with a path that contains no non-ASCII characters."
            )
        safe_path = (
            Path(local_app_data)
            / "SquishMac"
            / "Models"
            / requested_path.name
        )
        if not safe_path.is_file() or safe_path.stat().st_size != requested_path.stat().st_size:
            safe_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(requested_path, safe_path)
        return safe_path


def extract_audio(ffmpeg: Path, video: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(ffmpeg), "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(video), "-vn", "-ac", "1", "-ar", "44100",
            "-c:a", "pcm_s16le", str(output),
        ],
        check=True,
    )


@dataclass
class TrackedHand:
    hand_id: int
    handedness: str
    confidence: float
    landmarks: list[tuple[float, float, float]]

    @property
    def wrist(self) -> tuple[float, float]:
        return self.landmarks[0][0], self.landmarks[0][1]


class HandIdentityTracker:
    def __init__(self) -> None:
        self.previous: dict[int, tuple[float, float]] = {}
        self.last_seen: dict[int, float] = {}
        self.next_id = 0

    def assign(
        self,
        raw_hands: list[tuple[str, float, list[tuple[float, float, float]]]],
        timestamp: float,
    ) -> list[TrackedHand]:
        active_ids = [
            hand_id
            for hand_id, seen_at in self.last_seen.items()
            if timestamp - seen_at <= 0.75
        ]
        wrists = [(hand[2][0][0], hand[2][0][1]) for hand in raw_hands]
        assignments: dict[int, int] = {}

        if raw_hands and active_ids:
            possible_ids = active_ids[: len(raw_hands)]
            if len(possible_ids) < len(raw_hands):
                possible_ids.extend(
                    self._new_id() for _ in range(len(raw_hands) - len(possible_ids))
                )

            best_cost = math.inf
            best_order: tuple[int, ...] | None = None
            for order in permutations(possible_ids, len(raw_hands)):
                cost = sum(
                    distance(wrists[index], self.previous.get(hand_id, wrists[index]))
                    for index, hand_id in enumerate(order)
                )
                if cost < best_cost:
                    best_cost = cost
                    best_order = order
            if best_order is not None:
                assignments = dict(enumerate(best_order))

        for index in range(len(raw_hands)):
            if index not in assignments:
                assignments[index] = self._new_id()

        tracked: list[TrackedHand] = []
        for index, (handedness, confidence, landmarks) in enumerate(raw_hands):
            hand_id = assignments[index]
            wrist = wrists[index]
            self.previous[hand_id] = wrist
            self.last_seen[hand_id] = timestamp
            tracked.append(
                TrackedHand(
                    hand_id=hand_id,
                    handedness=handedness,
                    confidence=confidence,
                    landmarks=landmarks,
                )
            )
        return sorted(tracked, key=lambda hand: hand.hand_id)

    def _new_id(self) -> int:
        hand_id = self.next_id
        self.next_id += 1
        return hand_id


class MotionFeatureExtractor:
    def __init__(self) -> None:
        self.previous_tips: dict[str, tuple[float, float]] = {}
        self.previous_spread = 0.0
        self.previous_pressure = 0.0

    def process(self, timestamp: float, hands: list[TrackedHand]) -> dict[str, Any]:
        tips: list[tuple[str, tuple[float, float]]] = []
        hand_scales: list[float] = []
        compressions: list[float] = []
        pinches: list[float] = []

        for hand in hands:
            wrist = hand.wrist
            palm_scale = max(distance(wrist, _xy(hand.landmarks[9])), 0.025)
            hand_scales.append(palm_scale)
            openness = float(
                np.mean(
                    [
                        distance(wrist, _xy(hand.landmarks[index])) / palm_scale
                        for index in TIP_INDICES
                    ]
                )
            )
            compressions.append(clamp((2.35 - openness) / 1.25))
            thumb_index = distance(
                _xy(hand.landmarks[4]), _xy(hand.landmarks[8])
            ) / palm_scale
            pinches.append(clamp(1.0 - (thumb_index - 0.20) / 1.65))

            for tip_index in TIP_INDICES:
                key = f"{hand.hand_id}:{JOINT_NAMES[tip_index]}"
                tips.append((key, _xy(hand.landmarks[tip_index])))

        movements = [
            distance(point, self.previous_tips[key])
            for key, point in tips
            if key in self.previous_tips
        ]
        movement = clamp(float(np.mean(movements)) * 8.0) if movements else 0.0
        all_tip_points = [point for _, point in tips]
        spread = _maximum_distance(all_tip_points)
        centroid = _centroid(all_tip_points)

        cross_hand_pinch = 0.0
        if len(hands) >= 2:
            left_thumb = _xy(hands[0].landmarks[4])
            right_thumb = _xy(hands[1].landmarks[4])
            mean_scale = max(float(np.mean(hand_scales)), 0.025)
            normalized_separation = distance(left_thumb, right_thumb) / mean_scale
            cross_hand_pinch = clamp(1.0 - normalized_separation / 1.8)

        compression = float(np.mean(compressions)) if compressions else 0.0
        within_hand_pinch = max(pinches, default=0.0)
        pressure_estimate = clamp(
            compression * 0.46
            + within_hand_pinch * 0.16
            + cross_hand_pinch * 0.38
        )
        spread_delta = spread - self.previous_spread
        pressure_delta = pressure_estimate - self.previous_pressure

        self.previous_tips = dict(tips)
        self.previous_spread = spread
        self.previous_pressure = pressure_estimate

        return {
            "timestamp": round(timestamp, 6),
            "hand_count": len(hands),
            "fingertip_count": len(all_tip_points),
            "centroid_x": round(centroid[0], 6),
            "centroid_y": round(centroid[1], 6),
            "movement": round(movement, 6),
            "spread": round(spread, 6),
            "spread_delta": round(spread_delta, 6),
            "compression": round(compression, 6),
            "within_hand_pinch": round(within_hand_pinch, 6),
            "cross_hand_pinch": round(cross_hand_pinch, 6),
            "pressure_estimate": round(pressure_estimate, 6),
            "pressure_delta": round(pressure_delta, 6),
            "hands": [
                {
                    "id": hand.hand_id,
                    "handedness": hand.handedness,
                    "confidence": round(hand.confidence, 6),
                    "joints": {
                        name: {
                            "x": round(hand.landmarks[index][0], 6),
                            "y": round(hand.landmarks[index][1], 6),
                            "z": round(hand.landmarks[index][2], 6),
                        }
                        for index, name in enumerate(JOINT_NAMES)
                    },
                }
                for hand in hands
            ],
        }


def _xy(landmark: tuple[float, float, float]) -> tuple[float, float]:
    return landmark[0], landmark[1]


def _centroid(points: list[tuple[float, float]]) -> tuple[float, float]:
    if not points:
        return 0.0, 0.0
    return (
        float(np.mean([point[0] for point in points])),
        float(np.mean([point[1] for point in points])),
    )


def _maximum_distance(points: list[tuple[float, float]]) -> float:
    maximum = 0.0
    for left_index in range(len(points)):
        for right_index in range(left_index + 1, len(points)):
            maximum = max(
                maximum,
                distance(points[left_index], points[right_index]),
            )
    return clamp(maximum)


def track_hands(
    video: Path,
    model: Path,
    target_fps: float,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    capture = cv2.VideoCapture(str(video))
    if not capture.isOpened():
        raise RuntimeError(f"OpenCV could not open {video}")

    source_fps = float(capture.get(cv2.CAP_PROP_FPS))
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = frame_count / source_fps if source_fps > 0 else 0.0
    options = mp.tasks.vision.HandLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(model)),
        running_mode=mp.tasks.vision.RunningMode.VIDEO,
        num_hands=2,
        min_hand_detection_confidence=0.30,
        min_hand_presence_confidence=0.30,
        min_tracking_confidence=0.30,
    )
    identity_tracker = HandIdentityTracker()
    feature_extractor = MotionFeatureExtractor()
    records: list[dict[str, Any]] = []
    next_sample_time = 0.0
    frame_index = 0

    try:
        with mp.tasks.vision.HandLandmarker.create_from_options(options) as detector:
            while True:
                ok, frame = capture.read()
                if not ok:
                    break
                timestamp = (
                    float(capture.get(cv2.CAP_PROP_POS_MSEC)) / 1000.0
                    if source_fps <= 0
                    else frame_index / source_fps
                )
                frame_index += 1
                if timestamp + 1e-6 < next_sample_time:
                    continue
                next_sample_time += 1.0 / target_fps

                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                result = detector.detect_for_video(
                    mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb),
                    int(round(timestamp * 1000)),
                )
                raw_hands = []
                for index, landmarks in enumerate(result.hand_landmarks):
                    handedness = "unknown"
                    confidence = 0.0
                    if index < len(result.handedness) and result.handedness[index]:
                        category = result.handedness[index][0]
                        handedness = category.category_name or "unknown"
                        confidence = float(category.score or 0.0)
                    raw_hands.append(
                        (
                            handedness,
                            confidence,
                            [
                                (float(point.x), float(point.y), float(point.z))
                                for point in landmarks
                            ],
                        )
                    )

                hands = identity_tracker.assign(raw_hands, timestamp)
                record = feature_extractor.process(timestamp, hands)
                records.append(record)

                if len(records) % 75 == 0:
                    print(
                        f"Tracked {timestamp:5.1f}/{duration:5.1f}s "
                        f"({record['hand_count']} hands)"
                    )
    finally:
        capture.release()

    metadata = {
        "source_fps": source_fps,
        "analysis_fps": target_fps,
        "width": width,
        "height": height,
        "source_frame_count": frame_count,
        "analyzed_frame_count": len(records),
        "duration": duration,
    }
    calibrate_pressure(frames=records)
    return records, metadata


def calibrate_pressure(frames: list[dict[str, Any]]) -> None:
    raw_values = [
        frame["pressure_estimate"]
        for frame in frames
        if frame["hand_count"] > 0
    ]
    if not raw_values:
        return

    lower = float(np.percentile(raw_values, 8))
    upper = float(np.percentile(raw_values, 92))
    if upper - lower < 0.04:
        lower = min(raw_values)
        upper = max(raw_values)
    span = max(upper - lower, 0.04)
    previous = 0.0
    for frame in frames:
        raw = float(frame["pressure_estimate"])
        calibrated = (
            clamp((raw - lower) / span)
            if frame["hand_count"] > 0
            else 0.0
        )
        smoothed = calibrated * 0.62 + previous * 0.38
        frame["raw_pressure_estimate"] = round(raw, 6)
        frame["pressure_estimate"] = round(smoothed, 6)
        frame["pressure_delta"] = round(smoothed - previous, 6)
        previous = smoothed


def _draw_tracking_overlay(
    frame: np.ndarray,
    hands: list[TrackedHand],
    record: dict[str, Any],
) -> None:
    height, width = frame.shape[:2]
    colors = [(63, 228, 113), (255, 126, 67), (193, 93, 255)]
    for hand in hands:
        color = colors[hand.hand_id % len(colors)]
        points = [
            (int(clamp(point[0]) * width), int(clamp(point[1]) * height))
            for point in hand.landmarks
        ]
        for left, right in HAND_CONNECTIONS:
            cv2.line(frame, points[left], points[right], color, 3, cv2.LINE_AA)
        for index, point in enumerate(points):
            radius = 9 if index in TIP_INDICES else 5
            cv2.circle(frame, point, radius, color, -1, cv2.LINE_AA)
            if index in TIP_INDICES:
                cv2.circle(frame, point, radius + 4, (255, 255, 255), 2, cv2.LINE_AA)

    lines = [
        f"{record['timestamp']:.2f}s  hands {record['hand_count']}  tips {record['fingertip_count']}",
        f"movement {record['movement']:.2f}  pressure {record['pressure_estimate']:.2f}  spread {record['spread']:.2f}",
    ]
    for line_index, text in enumerate(lines):
        origin = (24, 42 + line_index * 34)
        cv2.putText(
            frame, text, origin, cv2.FONT_HERSHEY_SIMPLEX, 0.82,
            (0, 0, 0), 5, cv2.LINE_AA,
        )
        cv2.putText(
            frame, text, origin, cv2.FONT_HERSHEY_SIMPLEX, 0.82,
            (255, 255, 255), 2, cv2.LINE_AA,
        )


def render_tracking_video(
    source_video: Path,
    records: list[dict[str, Any]],
    output_video: Path,
    target_fps: float,
) -> None:
    capture = cv2.VideoCapture(str(source_video))
    if not capture.isOpened():
        raise RuntimeError(f"OpenCV could not reopen {source_video}")
    source_fps = float(capture.get(cv2.CAP_PROP_FPS))
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    output_video.parent.mkdir(parents=True, exist_ok=True)
    writer = cv2.VideoWriter(
        str(output_video),
        cv2.VideoWriter_fourcc(*"mp4v"),
        target_fps,
        (width, height),
    )
    if not writer.isOpened():
        capture.release()
        raise RuntimeError(f"OpenCV could not create {output_video}")

    next_sample_time = 0.0
    frame_index = 0
    record_index = 0
    try:
        while record_index < len(records):
            ok, frame = capture.read()
            if not ok:
                break
            timestamp = (
                float(capture.get(cv2.CAP_PROP_POS_MSEC)) / 1000.0
                if source_fps <= 0
                else frame_index / source_fps
            )
            frame_index += 1
            if timestamp + 1e-6 < next_sample_time:
                continue
            next_sample_time += 1.0 / target_fps

            record = records[record_index]
            record_index += 1
            hands = []
            for hand_value in record["hands"]:
                landmarks = [
                    (
                        hand_value["joints"][name]["x"],
                        hand_value["joints"][name]["y"],
                        hand_value["joints"][name]["z"],
                    )
                    for name in JOINT_NAMES
                ]
                hands.append(
                    TrackedHand(
                        hand_id=hand_value["id"],
                        handedness=hand_value["handedness"],
                        confidence=hand_value["confidence"],
                        landmarks=landmarks,
                    )
                )
            _draw_tracking_overlay(frame, hands, record)
            writer.write(frame)
    finally:
        capture.release()
        writer.release()


def mux_tracking_video(
    ffmpeg: Path,
    silent_video: Path,
    source_video: Path,
    output: Path,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(ffmpeg), "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(silent_video), "-i", str(source_video),
            "-map", "0:v:0", "-map", "1:a:0?",
            "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-c:a", "aac", "-b:a", "160k", "-shortest", str(output),
        ],
        check=True,
    )


def extract_tracking_poster(ffmpeg: Path, video: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(ffmpeg), "-y", "-hide_banner", "-loglevel", "error",
            "-ss", "0", "-i", str(video),
            "-frames:v", "1", "-q:v", "2", str(output),
        ],
        check=True,
    )


def analyze_audio(
    audio_path: Path,
    material_category: str,
    material_id: str,
) -> tuple[np.ndarray, int, list[dict[str, Any]]]:
    samples, sample_rate = sf.read(audio_path, always_2d=False)
    if samples.ndim > 1:
        samples = np.mean(samples, axis=1)
    samples = np.asarray(samples, dtype=np.float64)
    frame_size = 2048
    hop_size = 512
    window = np.hanning(frame_size)
    frame_count = max(0, 1 + (len(samples) - frame_size) // hop_size)
    rms_values = np.zeros(frame_count)
    peak_values = np.zeros(frame_count)
    zcr_values = np.zeros(frame_count)
    centroid_values = np.zeros(frame_count)
    rolloff_values = np.zeros(frame_count)
    flatness_values = np.zeros(frame_count)
    flux_values = np.zeros(frame_count)
    previous_spectrum: np.ndarray | None = None
    frequencies = np.fft.rfftfreq(frame_size, 1.0 / sample_rate)

    for index in range(frame_count):
        start = index * hop_size
        frame = samples[start : start + frame_size]
        rms_values[index] = math.sqrt(float(np.mean(frame * frame)))
        peak_values[index] = float(np.max(np.abs(frame)))
        zcr_values[index] = float(
            np.mean(np.signbit(frame[:-1]) != np.signbit(frame[1:]))
        )
        spectrum = np.abs(np.fft.rfft(frame * window))
        total = float(np.sum(spectrum)) + 1e-12
        power = spectrum * spectrum + 1e-18
        flatness_values[index] = float(
            np.exp(np.mean(np.log(power))) / np.mean(power)
        )
        centroid_values[index] = float(np.sum(spectrum * frequencies) / total)
        cumulative = np.cumsum(spectrum)
        rolloff_index = min(
            int(np.searchsorted(cumulative, cumulative[-1] * 0.85)),
            len(frequencies) - 1,
        )
        rolloff_values[index] = float(frequencies[rolloff_index])
        if previous_spectrum is not None:
            flux_values[index] = float(
                np.sum(np.maximum(spectrum - previous_spectrum, 0.0))
                / (np.sum(previous_spectrum) + 1e-12)
            )
        previous_spectrum = spectrum

    rms_onset = np.maximum(np.diff(np.log1p(rms_values * 80), prepend=0), 0)
    onset_score = _robust_scale(rms_onset) * 0.58 + _robust_scale(flux_values) * 0.42
    if len(onset_score) >= 5:
        onset_score = np.convolve(onset_score, np.ones(3) / 3, mode="same")
    minimum_distance = max(1, int(0.085 * sample_rate / hop_size))
    height = max(0.55, float(np.percentile(onset_score, 68)))
    peaks, properties = find_peaks(
        onset_score,
        height=height,
        prominence=0.30,
        distance=minimum_distance,
    )

    if len(peaks) > 72:
        strengths = properties["peak_heights"]
        selected = np.argsort(strengths)[-72:]
        peaks = np.sort(peaks[selected])

    events: list[dict[str, Any]] = []
    minimum_meaningful_peak = max(
        0.003,
        float(np.percentile(peak_values, 75)) * 1.78,
    )
    for frame_index in peaks:
        timestamp = frame_index * hop_size / sample_rate
        local_start = max(0, frame_index - 3)
        local_end = min(frame_count, frame_index + 5)
        rms = float(np.max(rms_values[local_start:local_end]))
        peak = float(np.max(peak_values[local_start:local_end]))
        zcr = float(np.mean(zcr_values[local_start:local_end]))
        centroid = float(np.mean(centroid_values[local_start:local_end]))
        rolloff = float(np.mean(rolloff_values[local_start:local_end]))
        spectral_flatness = float(
            np.mean(flatness_values[local_start:local_end])
        )
        crest = peak / max(rms, 1e-9)
        score = float(onset_score[frame_index])
        if peak < minimum_meaningful_peak:
            continue
        acoustic_texture = classify_audio_texture(
            rms=rms,
            peak=peak,
            zcr=zcr,
            centroid=centroid,
            crest=crest,
        )
        texture = semantic_audio_texture(
            acoustic_texture,
            material_category,
            material_id,
        )
        events.append(
            {
                "id": len(events),
                "timestamp": round(timestamp, 6),
                "rms": round(rms, 7),
                "peak": round(peak, 7),
                "zero_crossing_rate": round(zcr, 7),
                "spectral_centroid_hz": round(centroid, 3),
                "spectral_rolloff_hz": round(rolloff, 3),
                "spectral_flatness": round(spectral_flatness, 7),
                "crest_factor": round(crest, 4),
                "onset_score": round(score, 4),
                "voice_likelihood": round(
                    estimate_voice_likelihood(
                        samples,
                        int(sample_rate),
                        timestamp,
                    ),
                    6,
                ),
                "acoustic_texture": acoustic_texture,
                "suggested_texture": texture,
                "clip_start": round(max(0.0, timestamp - 0.075), 6),
                "clip_end": round(
                    min(len(samples) / sample_rate, timestamp + 0.42), 6
                ),
                "gesture_kind": None,
                "clip_path": None,
            }
        )
    return samples, int(sample_rate), merge_audio_events(events)


def merge_audio_events(
    events: list[dict[str, Any]],
    cluster_window: float = 0.16,
) -> list[dict[str, Any]]:
    merged: list[dict[str, Any]] = []
    for event in events:
        if not merged or event["timestamp"] - merged[-1]["timestamp"] >= cluster_window:
            merged.append(event)
            continue

        previous = merged[-1]
        clip_start = min(previous["clip_start"], event["clip_start"])
        clip_end = max(previous["clip_end"], event["clip_end"])
        if event["onset_score"] > previous["onset_score"]:
            event["clip_start"] = clip_start
            event["clip_end"] = clip_end
            merged[-1] = event
        else:
            previous["clip_start"] = clip_start
            previous["clip_end"] = clip_end

    for index, event in enumerate(merged):
        event["id"] = index
    return merged


def _robust_scale(values: np.ndarray) -> np.ndarray:
    median = float(np.median(values))
    deviation = float(np.median(np.abs(values - median)))
    return np.maximum((values - median) / max(deviation * 1.4826, 1e-8), 0.0)


def estimate_voice_likelihood(
    samples: np.ndarray,
    sample_rate: int,
    timestamp: float,
) -> float:
    start = max(0, int((timestamp - 0.04) * sample_rate))
    end = min(len(samples), int((timestamp + 0.34) * sample_rate))
    segment = np.asarray(samples[start:end], dtype=np.float64)
    frame_size = max(64, int(sample_rate * 0.030))
    hop_size = max(32, int(sample_rate * 0.010))
    if len(segment) < frame_size:
        return 0.0

    minimum_lag = max(1, int(sample_rate / 400))
    maximum_lag = min(frame_size - 2, int(sample_rate / 80))
    periodicities: list[float] = []
    active_frames = 0
    voiced_frames = 0

    for offset in range(0, len(segment) - frame_size + 1, hop_size):
        frame = segment[offset : offset + frame_size]
        frame = frame - float(np.mean(frame))
        rms = math.sqrt(float(np.mean(frame * frame)))
        if rms < 0.0015:
            continue
        active_frames += 1
        correlation = np.correlate(frame, frame, mode="full")[frame_size - 1 :]
        denominator = max(float(correlation[0]), 1e-12)
        periodicity = float(
            np.max(correlation[minimum_lag : maximum_lag + 1])
            / denominator
        )
        periodicity = clamp(periodicity)
        periodicities.append(periodicity)
        if periodicity >= 0.48:
            voiced_frames += 1

    if not periodicities:
        return 0.0
    periodicity_high = percentile(periodicities, 0.75)
    sustained_ratio = voiced_frames / max(active_frames, 1)
    return clamp(periodicity_high * 0.68 + sustained_ratio * 0.32)


def select_slime_only_audio(
    events: list[dict[str, Any]],
    manual_exclusions: list[dict[str, Any]] | None = None,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    accepted: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    exclusions = manual_exclusions or []

    for event in events:
        is_slime_gesture = str(event.get("gesture_kind") or "").startswith("slime_")
        voice_likelihood = float(event.get("voice_likelihood") or 0.0)
        crest = float(event.get("crest_factor") or 0.0)
        flatness = float(event.get("spectral_flatness") or 0.0)
        transient_score = clamp((crest - 2.0) / 7.0)
        noise_texture_score = clamp(flatness / 0.08)
        slime_likelihood = clamp(
            (0.58 if is_slime_gesture else 0.0)
            + transient_score * 0.24
            + noise_texture_score * 0.18
            - voice_likelihood * 0.42
        )
        event["slime_likelihood"] = round(slime_likelihood, 6)

        exclusion = next(
            (
                item
                for item in exclusions
                if item["start"] <= event["timestamp"] <= item["end"]
            ),
            None,
        )
        rejection_reason: str | None = None
        if exclusion is not None:
            rejection_reason = "manual_audio_exclusion"
            event["exclusion_reason"] = exclusion["reason"]
        elif not is_slime_gesture:
            rejection_reason = "not_aligned_with_slime_gesture"
        elif voice_likelihood >= 0.72:
            rejection_reason = "possible_voice"
        elif slime_likelihood < 0.44:
            rejection_reason = "low_slime_likelihood"

        if rejection_reason is None:
            event["selection_status"] = "accepted"
            accepted.append(event)
        else:
            event["selection_status"] = "rejected"
            event["rejection_reason"] = rejection_reason
            event["clip_path"] = None
            rejected.append(event)

    for index, event in enumerate(accepted):
        event["id"] = index
    for index, event in enumerate(rejected):
        event["id"] = index
    return accepted, rejected


def load_audio_exclusions(path: Path | None) -> list[dict[str, Any]]:
    if path is None:
        return []
    if not path.is_file():
        raise FileNotFoundError(path)

    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, list):
        raise ValueError("--audio-exclusions must contain a JSON array")

    exclusions: list[dict[str, Any]] = []
    for index, item in enumerate(value):
        if not isinstance(item, dict):
            raise ValueError(f"Audio exclusion {index} must be an object")
        start = float(item.get("start", -1))
        end = float(item.get("end", -1))
        reason = str(item.get("reason") or "").strip()
        if start < 0 or end <= start or not reason:
            raise ValueError(
                f"Audio exclusion {index} needs start >= 0, end > start, and reason"
            )
        exclusions.append(
            {
                "start": round(start, 6),
                "end": round(end, 6),
                "reason": reason,
            }
        )
    return exclusions


def isolate_audio_clip_boundaries(events: list[dict[str, Any]]) -> None:
    for index, event in enumerate(events):
        timestamp = float(event["timestamp"])
        start = max(float(event["clip_start"]), timestamp - 0.055)
        end = min(float(event["clip_end"]), timestamp + 0.30)
        if index > 0:
            previous_timestamp = float(events[index - 1]["timestamp"])
            start = max(start, (previous_timestamp + timestamp) / 2 + 0.008)
        if index + 1 < len(events):
            next_timestamp = float(events[index + 1]["timestamp"])
            end = min(end, (timestamp + next_timestamp) / 2 - 0.008)

        if end - start < 0.09:
            start = max(0.0, timestamp - 0.035)
            end = timestamp + 0.065
        event["clip_start"] = round(start, 6)
        event["clip_end"] = round(end, 6)


def classify_audio_texture(
    rms: float,
    peak: float,
    zcr: float,
    centroid: float,
    crest: float,
) -> str:
    if crest >= 5.0 and centroid >= 1700:
        return "brittle_crack"
    if centroid >= 3000 and crest >= 2.8:
        return "micro_crackle"
    if crest >= 4.0:
        return "suction_pop"
    if rms >= 0.055 and centroid <= 1900 and crest <= 4.5:
        return "dense_squish"
    if centroid <= 2600:
        return "wet_friction"
    return "bubble_cluster"


def semantic_audio_texture(
    acoustic_texture: str,
    material_category: str,
    material_id: str,
) -> str:
    category = material_category.lower()
    if material_id.lower() == "doctor-putty-pink":
        return {
            "brittle_crack": "stretch_too_fast_failure",
            "micro_crackle": "putty_soft_crackle",
        }.get(acoustic_texture, acoustic_texture)
    if "wax" in category or "shell" in category:
        return acoustic_texture
    if "butter" in category or "clay" in category:
        return {
            "brittle_crack": "clay_snap",
            "micro_crackle": "soft_crackle",
        }.get(acoustic_texture, acoustic_texture)
    return {
        "brittle_crack": "slime_snap",
        "micro_crackle": "micro_pop",
    }.get(acoustic_texture, acoustic_texture)


def infer_gestures(
    frames: list[dict[str, Any]],
    audio_events: list[dict[str, Any]],
    material_category: str,
    analysis_fps: float,
) -> list[dict[str, Any]]:
    if not frames:
        return []

    movement = np.asarray([frame["movement"] for frame in frames])
    pressure = np.asarray([frame["pressure_estimate"] for frame in frames])
    spread = np.asarray([frame["spread"] for frame in frames])
    pressure_change = np.abs(np.diff(pressure, prepend=pressure[0]))
    spread_change = np.abs(np.diff(spread, prepend=spread[0]))
    activity = movement * 0.55 + pressure_change * 0.30 + spread_change * 0.15
    prominence = max(0.015, float(np.percentile(activity, 55)) * 0.40)
    peak_indices, _ = find_peaks(
        activity,
        prominence=prominence,
        distance=max(1, int(analysis_fps * 0.14)),
    )
    detected_indices = [
        index for index, frame in enumerate(frames) if frame["hand_count"] > 0
    ]
    candidate_indices = {
        int(index)
        for index in peak_indices
        if frames[int(index)]["hand_count"] > 0
    }

    for event in audio_events:
        nearest_detected = min(
            detected_indices,
            key=lambda index: abs(frames[index]["timestamp"] - event["timestamp"]),
            default=None,
        )
        if (
            nearest_detected is not None
            and abs(
                frames[nearest_detected]["timestamp"] - event["timestamp"]
            ) <= 0.40
        ):
            candidate_indices.add(nearest_detected)

    gestures: list[dict[str, Any]] = []
    last_time_by_kind: dict[str, float] = {}
    last_global_time = -math.inf
    is_wax_shell = "wax" in material_category or "shell" in material_category

    for index in sorted(candidate_indices):
        frame = frames[index]
        timestamp = float(frame["timestamp"])
        if timestamp < 0.30 or frame["hand_count"] == 0:
            continue
        nearest_audio = _nearest_audio(audio_events, timestamp, maximum_delta=0.28)
        texture = nearest_audio["suggested_texture"] if nearest_audio else None
        previous = frame
        for previous_index in range(index - 1, -1, -1):
            candidate = frames[previous_index]
            if timestamp - candidate["timestamp"] > 0.40:
                break
            if candidate["hand_count"] > 0:
                previous = candidate
                break
        spread_delta = frame["spread"] - previous["spread"]
        pressure_delta = frame["pressure_estimate"] - previous["pressure_estimate"]

        if (
            is_wax_shell
            and texture in {"brittle_crack", "micro_crackle"}
            and frame["pressure_estimate"] >= 0.24
            and abs(nearest_audio["timestamp"] - timestamp) <= 0.10
        ):
            kind = "wax_crack"
        elif (
            texture == "stretch_too_fast_failure"
            and nearest_audio is not None
            and abs(nearest_audio["timestamp"] - timestamp) <= 0.16
        ):
            kind = "stretch_too_fast_failure"
        elif (
            is_wax_shell
            and frame["pressure_estimate"] >= 0.72
            and (
                pressure_delta >= 0.075
                or (
                    previous["pressure_estimate"] < 0.58
                    and frame["movement"] >= 0.10
                )
            )
        ):
            kind = "wax_crush"
        elif (
            is_wax_shell
            and (
                pressure_delta >= 0.055
                or (
                    frame["pressure_estimate"] >= 0.36
                    and frame["movement"] < 0.19
                )
            )
        ):
            kind = "wax_press"
        elif frame["movement"] >= 0.16 and spread_delta >= 0.012:
            kind = "slime_stretch"
        elif frame["movement"] >= 0.055:
            kind = "slime_knead"
        elif frame["pressure_estimate"] >= 0.30:
            kind = "slime_press"
        else:
            continue

        minimum_intervals = {
            "wax_crack": 0.14,
            "wax_crush": 0.50,
            "wax_press": 0.34,
            "slime_stretch": 0.24,
            "stretch_too_fast_failure": 0.60,
            "slime_knead": 0.24,
            "slime_press": 0.30,
        }
        minimum_interval = minimum_intervals[kind]
        if timestamp - last_global_time < 0.10:
            continue
        if timestamp - last_time_by_kind.get(kind, -math.inf) < minimum_interval:
            continue
        last_global_time = timestamp
        last_time_by_kind[kind] = timestamp
        intensity = clamp(
            frame["movement"] * 0.36
            + frame["pressure_estimate"] * 0.46
            + min(frame["fingertip_count"], 10) / 10.0 * 0.18
        )
        if kind == "stretch_too_fast_failure":
            intensity = max(0.70, intensity)
        gestures.append(
            {
                "id": len(gestures),
                "timestamp": round(timestamp, 6),
                "kind": kind,
                "intensity": round(intensity, 6),
                "motion_frame_index": index,
                "audio_event_id": nearest_audio["id"] if nearest_audio else None,
                "audio_offset": (
                    round(nearest_audio["timestamp"] - timestamp, 6)
                    if nearest_audio
                    else None
                ),
            }
        )

    for audio_event in audio_events:
        nearest_gesture = min(
            gestures,
            key=lambda gesture: abs(
                gesture["timestamp"] - audio_event["timestamp"]
            ),
            default=None,
        )
        if (
            nearest_gesture is not None
            and abs(nearest_gesture["timestamp"] - audio_event["timestamp"]) <= 0.32
        ):
            audio_event["gesture_kind"] = nearest_gesture["kind"]
    return gestures


def _nearest_audio(
    events: list[dict[str, Any]],
    timestamp: float,
    maximum_delta: float,
) -> dict[str, Any] | None:
    event = min(
        events,
        key=lambda candidate: abs(candidate["timestamp"] - timestamp),
        default=None,
    )
    if event is None or abs(event["timestamp"] - timestamp) > maximum_delta:
        return None
    return event


def export_audio_clips(
    samples: np.ndarray,
    sample_rate: int,
    events: list[dict[str, Any]],
    output_root: Path,
    clean_slime_audio: bool = False,
    highpass_hz: float = 70.0,
    lowpass_hz: float = 16000.0,
) -> None:
    if output_root.exists():
        shutil.rmtree(output_root)
    for event in events:
        gesture = event["gesture_kind"] or "unmapped"
        texture = event["suggested_texture"]
        folder = output_root / gesture
        folder.mkdir(parents=True, exist_ok=True)
        file_name = (
            f"{event['id']:03d}-{event['timestamp']:07.3f}s-{texture}.wav"
        )
        output = folder / file_name
        start = int(event["clip_start"] * sample_rate)
        end = int(event["clip_end"] * sample_rate)
        clip = np.array(samples[start:end], dtype=np.float64, copy=True)
        if clean_slime_audio:
            clip = clean_slime_clip(
                clip,
                sample_rate,
                highpass_hz=highpass_hz,
                lowpass_hz=lowpass_hz,
            )
            clip = polish_slime_clip(clip, sample_rate)
        else:
            fade_size = min(int(sample_rate * 0.006), len(clip) // 2)
            if fade_size > 0:
                fade = np.linspace(0.0, 1.0, fade_size)
                clip[:fade_size] *= fade
                clip[-fade_size:] *= fade[::-1]
        sf.write(output, clip, sample_rate, subtype="PCM_16")
        event["clip_path"] = output.relative_to(output_root.parent.parent).as_posix()


def polish_slime_clip(
    clip: np.ndarray,
    sample_rate: int,
    peak_ceiling_db: float = -10.0,
    rms_ceiling_db: float = -32.0,
) -> np.ndarray:
    if len(clip) == 0:
        return clip

    polished = np.asarray(clip, dtype=np.float64).copy()
    peak = float(np.max(np.abs(polished)))
    rms = float(np.sqrt(np.mean(np.square(polished))))
    peak_ceiling = 10.0 ** (peak_ceiling_db / 20.0)
    rms_ceiling = 10.0 ** (rms_ceiling_db / 20.0)
    gain = 1.0
    if peak > 0:
        gain = min(gain, peak_ceiling / peak)
    if rms > 0:
        gain = min(gain, rms_ceiling / rms)
    polished *= gain

    fade_in_size = min(int(sample_rate * 0.012), len(polished) // 2)
    fade_out_size = min(int(sample_rate * 0.030), len(polished) // 2)
    if fade_in_size > 0:
        phase = np.linspace(0.0, np.pi / 2.0, fade_in_size)
        polished[:fade_in_size] *= np.square(np.sin(phase))
    if fade_out_size > 0:
        phase = np.linspace(np.pi / 2.0, 0.0, fade_out_size)
        polished[-fade_out_size:] *= np.square(np.sin(phase))
    return polished


def clean_slime_clip(
    clip: np.ndarray,
    sample_rate: int,
    highpass_hz: float = 70.0,
    lowpass_hz: float = 16000.0,
) -> np.ndarray:
    if len(clip) < 32:
        return clip

    clip = np.asarray(clip, dtype=np.float64)
    clip = clip - float(np.mean(clip))
    highpass_frequency = min(max(highpass_hz, 20.0), sample_rate * 0.40)
    highpass = butter(
        2,
        highpass_frequency,
        btype="highpass",
        fs=sample_rate,
        output="sos",
    )
    lowpass_frequency = min(
        max(lowpass_hz, highpass_frequency + 100.0),
        sample_rate * 0.45,
    )
    lowpass = butter(
        2,
        lowpass_frequency,
        btype="lowpass",
        fs=sample_rate,
        output="sos",
    )
    filtered = sosfiltfilt(highpass, clip)
    filtered = sosfiltfilt(lowpass, filtered)

    frequencies, times, spectrum = stft(
        filtered,
        fs=sample_rate,
        nperseg=1024,
        noverlap=768,
        boundary="zeros",
    )
    del frequencies
    magnitude = np.abs(spectrum)
    phase = np.exp(1j * np.angle(spectrum))
    noise_columns = max(1, min(magnitude.shape[1], int(0.05 * sample_rate / 256)))
    noise_floor = np.median(magnitude[:, :noise_columns], axis=1, keepdims=True)
    cleaned_magnitude = np.maximum(
        magnitude - noise_floor * 1.15,
        magnitude * 0.10,
    )
    _, cleaned = istft(
        cleaned_magnitude * phase,
        fs=sample_rate,
        nperseg=1024,
        noverlap=768,
        input_onesided=True,
    )
    cleaned = np.asarray(cleaned[: len(clip)], dtype=np.float64)
    if len(cleaned) < len(clip):
        cleaned = np.pad(cleaned, (0, len(clip) - len(cleaned)))

    peak = float(np.max(np.abs(cleaned)))
    if peak > 1e-8:
        cleaned *= min(18.0, 0.72 / peak)
    return np.clip(cleaned, -0.85, 0.85)


def learned_profile(frames: list[dict[str, Any]]) -> dict[str, float]:
    movement = [frame["movement"] for frame in frames]
    pressure = [frame["pressure_estimate"] for frame in frames]
    spread = [frame["spread"] for frame in frames]
    pressure_median = percentile(pressure, 0.50)
    movement_high = percentile(movement, 0.90)
    return {
        "movement_median": round(percentile(movement, 0.50), 6),
        "movement_high": round(movement_high, 6),
        "pressure_median": round(pressure_median, 6),
        "pressure_high": round(percentile(pressure, 0.90), 6),
        "spread_median": round(percentile(spread, 0.50), 6),
        "suggested_response": round(clamp(1.15 - pressure_median * 0.35, 0.65, 1.55), 6),
        "suggested_sound_density": round(clamp(0.8 + movement_high * 0.65, 0.65, 1.65), 6),
    }


def input_specific_tuning(
    frames: list[dict[str, Any]],
    material_category: str,
) -> dict[str, dict[str, Any]]:
    detected = [frame for frame in frames if frame["hand_count"] > 0]
    movement = [float(frame["movement"]) for frame in detected]
    pressure = [float(frame["pressure_estimate"]) for frame in detected]
    spread = [float(frame["spread"]) for frame in detected]
    movement_high = percentile(movement, 0.90)
    pressure_median = percentile(pressure, 0.50)

    camera_response = clamp(
        1.15 - pressure_median * 0.35,
        0.65,
        1.55,
    )
    camera_sound_density = clamp(
        0.8 + movement_high * 0.65,
        0.65,
        1.65,
    )
    camera_knead = clamp(
        percentile(movement, 0.25) * 0.85,
        0.055,
        0.12,
    )
    camera_stretch = clamp(
        percentile(movement, 0.70) * 0.92,
        0.16,
        0.32,
    )
    camera_spread = clamp(
        percentile(spread, 0.60),
        0.24,
        0.42,
    )
    camera_press = clamp(
        percentile(pressure, 0.25) * 0.94,
        0.26,
        0.46,
    )

    category = material_category.lower()
    if "clear" in category or "jelly" in category:
        trackpad_stretch = 0.14
        trackpad_response = 0.96
        trackpad_sound_density = 1.08
    elif "butter" in category or "clay" in category:
        trackpad_stretch = 0.18
        trackpad_response = 0.90
        trackpad_sound_density = 0.92
    else:
        trackpad_stretch = 0.16
        trackpad_response = 1.0
        trackpad_sound_density = 1.0

    return {
        "camera": {
            "calibration_basis": "video_landmark_percentiles",
            "response": round(camera_response, 6),
            "sound_density": round(camera_sound_density, 6),
            "minimum_fingertip_count": 3,
            "knead_movement_threshold": round(camera_knead, 6),
            "stretch_movement_threshold": round(camera_stretch, 6),
            "stretch_spread_threshold": round(camera_spread, 6),
            "press_pressure_threshold": round(camera_press, 6),
        },
        "trackpad": {
            "calibration_basis": (
                "material_prior_pending_force_touch_session"
            ),
            "response": trackpad_response,
            "sound_density": trackpad_sound_density,
            "minimum_finger_count": 3,
            "knead_movement_threshold": 0.025,
            "stretch_movement_threshold": trackpad_stretch,
            "minimum_live_intensity": 0.28,
        },
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--material-id", required=True)
    parser.add_argument("--material-name", required=True)
    parser.add_argument("--material-category", required=True)
    parser.add_argument("--classification-confidence", type=float, default=0.5)
    parser.add_argument("--outer-texture", default="")
    parser.add_argument("--core-texture", default="")
    parser.add_argument("--notes", default="")
    parser.add_argument("--fast-stretch-failure-threshold", type=float)
    parser.add_argument("--failure-sound-pack-id")
    parser.add_argument("--interaction-summary", default="")
    parser.add_argument("--analysis-fps", type=float, default=15.0)
    parser.add_argument(
        "--slime-only-audio",
        action="store_true",
        help=(
            "Keep only audio aligned with slime gestures and reject candidates "
            "with high voice likelihood."
        ),
    )
    parser.add_argument(
        "--audio-exclusions",
        type=Path,
        help=(
            "JSON array of timestamp ranges to reject before slime-only audio "
            "selection. Each item needs start, end, and reason."
        ),
    )
    parser.add_argument(
        "--audio-highpass-hz",
        type=float,
        default=70.0,
        help="High-pass frequency used when cleaning slime clips (default: 70).",
    )
    parser.add_argument(
        "--audio-lowpass-hz",
        type=float,
        default=16000.0,
        help="Low-pass frequency used when cleaning slime clips (default: 16000).",
    )
    parser.add_argument(
        "--isolate-audio-clips",
        action="store_true",
        help="Shorten neighboring event clips so their source ranges do not overlap.",
    )
    parser.add_argument("--model", type=Path)
    parser.add_argument("--ffmpeg")
    return parser.parse_args()


def main() -> None:
    args = parse_arguments()
    video = args.video.resolve()
    output = args.output.resolve()
    if not video.is_file():
        raise FileNotFoundError(video)
    if args.slime_only_audio and (
        "wax" in args.material_category.lower()
        or "shell" in args.material_category.lower()
    ):
        raise ValueError("--slime-only-audio cannot be used for wax material")
    if args.audio_exclusions and not args.slime_only_audio:
        raise ValueError("--audio-exclusions requires --slime-only-audio")
    if args.audio_highpass_hz < 20:
        raise ValueError("--audio-highpass-hz must be at least 20")
    if args.audio_lowpass_hz <= args.audio_highpass_hz + 100:
        raise ValueError(
            "--audio-lowpass-hz must be at least 100 Hz above the high-pass"
        )

    ffmpeg = find_ffmpeg(args.ffmpeg)
    audio_exclusions = load_audio_exclusions(
        args.audio_exclusions.resolve() if args.audio_exclusions else None
    )
    requested_model = (
        args.model.resolve()
        if args.model
        else output.parent / "models" / "hand_landmarker.task"
    )
    ensure_model(requested_model)
    model = native_safe_model_path(requested_model)
    output.mkdir(parents=True, exist_ok=True)
    audio_path = output / "audio" / "source.wav"
    silent_tracking = output / "overlays" / "tracking-silent.mp4"
    tracking_video = output / "overlays" / "tracking.mp4"
    tracking_poster = output / "overlays" / "poster.jpg"

    print("Extracting source audio")
    extract_audio(ffmpeg, video, audio_path)
    print("Tracking hands and fingertips")
    frames, video_metadata = track_hands(
        video=video,
        model=model,
        target_fps=args.analysis_fps,
    )
    render_tracking_video(
        source_video=video,
        records=frames,
        output_video=silent_tracking,
        target_fps=args.analysis_fps,
    )
    print("Analyzing audio events")
    samples, sample_rate, audio_events = analyze_audio(
        audio_path,
        args.material_category,
        args.material_id,
    )
    print("Aligning motion and sound")
    gestures = infer_gestures(
        frames=frames,
        audio_events=audio_events,
        material_category=args.material_category,
        analysis_fps=args.analysis_fps,
    )
    raw_audio_event_count = len(audio_events)
    rejected_audio_events: list[dict[str, Any]] = []
    if args.slime_only_audio:
        audio_events, rejected_audio_events = select_slime_only_audio(
            audio_events,
            manual_exclusions=audio_exclusions,
        )
        gestures = infer_gestures(
            frames=frames,
            audio_events=audio_events,
            material_category=args.material_category,
            analysis_fps=args.analysis_fps,
        )
    if args.isolate_audio_clips:
        isolate_audio_clip_boundaries(audio_events)
    export_audio_clips(
        samples=samples,
        sample_rate=sample_rate,
        events=audio_events,
        output_root=output / "audio" / "clips",
        clean_slime_audio=args.slime_only_audio,
        highpass_hz=args.audio_highpass_hz,
        lowpass_hz=args.audio_lowpass_hz,
    )
    mux_tracking_video(ffmpeg, silent_tracking, video, tracking_video)
    extract_tracking_poster(ffmpeg, tracking_video, tracking_poster)
    silent_tracking.unlink(missing_ok=True)

    motion_path = output / "motion" / "landmarks.json"
    audio_events_path = output / "audio" / "events.json"
    rejected_audio_events_path = output / "audio" / "rejected-events.json"
    audio_exclusions_path = output / "audio" / "exclusions.json"
    gesture_path = output / "events" / "gesture_timeline.json"
    write_json(motion_path, frames)
    write_json(audio_events_path, audio_events)
    write_json(rejected_audio_events_path, rejected_audio_events)
    write_json(audio_exclusions_path, audio_exclusions)
    write_json(gesture_path, gestures)

    gesture_counts: dict[str, int] = {}
    texture_counts: dict[str, int] = {}
    hand_count_distribution = {
        str(hand_count): sum(
            1 for frame in frames if frame["hand_count"] == hand_count
        )
        for hand_count in range(3)
    }
    for gesture in gestures:
        gesture_counts[gesture["kind"]] = gesture_counts.get(gesture["kind"], 0) + 1
    for event in audio_events:
        texture = event["suggested_texture"]
        texture_counts[texture] = texture_counts.get(texture, 0) + 1

    manifest = {
        "schema_version": 2,
        "dataset_id": f"{args.material_id}__{video.stem}",
        "material_profile": {
            "id": args.material_id,
            "display_name": args.material_name,
            "category": args.material_category,
            "classification_confidence": round(
                clamp(args.classification_confidence), 4
            ),
            "outer_texture": args.outer_texture,
            "core_texture": args.core_texture,
            "notes": args.notes,
            "interaction_rules": {
                "fast_stretch_failure_movement_threshold": (
                    round(clamp(args.fast_stretch_failure_threshold), 6)
                    if args.fast_stretch_failure_threshold is not None
                    else None
                ),
                "failure_sound_pack_id": args.failure_sound_pack_id,
                "interaction_summary": args.interaction_summary,
            },
        },
        "source": {
            "file_name": video.name,
            "sha256": sha256(video),
            "duration": round(video_metadata["duration"], 6),
            "has_audio": True,
        },
        "video": video_metadata,
        "summary": {
            "frames_with_hands": sum(
                1 for frame in frames if frame["hand_count"] > 0
            ),
            "hand_count_distribution": hand_count_distribution,
            "tracking_gap_count": sum(
                1
                for index, frame in enumerate(frames)
                if frame["hand_count"] == 0
                and (
                    index == 0
                    or frames[index - 1]["hand_count"] > 0
                )
            ),
            "hand_detection_coverage": round(
                sum(1 for frame in frames if frame["hand_count"] > 0)
                / max(len(frames), 1),
                6,
            ),
            "audio_event_count": len(audio_events),
            "raw_audio_event_count": raw_audio_event_count,
            "rejected_audio_event_count": len(rejected_audio_events),
            "manual_audio_exclusion_count": sum(
                1
                for event in rejected_audio_events
                if event.get("rejection_reason") == "manual_audio_exclusion"
            ),
            "gesture_event_count": len(gestures),
            "gesture_counts": gesture_counts,
            "audio_texture_counts": texture_counts,
        },
        "learned_profile": learned_profile(frames),
        "input_tuning": input_specific_tuning(
            frames,
            args.material_category,
        ),
        "audio_selection": {
            "mode": (
                "slime_only_cross_modal"
                if args.slime_only_audio
                else "all_detected_onsets"
            ),
            "voice_rejection_threshold": (
                0.72 if args.slime_only_audio else None
            ),
            "requires_slime_gesture_alignment": args.slime_only_audio,
            "manual_exclusions": audio_exclusions,
            "clip_boundary_mode": (
                "non_overlapping" if args.isolate_audio_clips else "onset_window"
            ),
            "clip_processing": (
                f"{args.audio_highpass_hz:g}Hz high-pass, "
                f"{args.audio_lowpass_hz:g}Hz low-pass, conservative spectral "
                "gate, bounded peak normalization"
                if args.slime_only_audio
                else "source amplitude with short edge fades"
            ),
        },
        "artifacts": {
            "motion_frames": motion_path.relative_to(output).as_posix(),
            "audio_events": audio_events_path.relative_to(output).as_posix(),
            "rejected_audio_events": (
                rejected_audio_events_path.relative_to(output).as_posix()
            ),
            "audio_exclusions": (
                audio_exclusions_path.relative_to(output).as_posix()
            ),
            "gesture_timeline": gesture_path.relative_to(output).as_posix(),
            "tracking_video": tracking_video.relative_to(output).as_posix(),
            "tracking_poster": tracking_poster.relative_to(output).as_posix(),
            "source_audio": audio_path.relative_to(output).as_posix(),
            "audio_clip_root": "audio/clips",
        },
    }
    write_json(output / "dataset.json", manifest)
    print(json.dumps(manifest["summary"], ensure_ascii=False, indent=2))
    print(f"Dataset written to {output}")


if __name__ == "__main__":
    main()
