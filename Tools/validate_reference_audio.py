#!/usr/bin/env python3
"""Validate polished PCM reference sounds before packaging SquishMac."""

from __future__ import annotations

import argparse
import hashlib
import math
import struct
import sys
import wave
from pathlib import Path


def amplitude_to_db(amplitude: float) -> float:
    if amplitude <= 0:
        return -math.inf
    return 20.0 * math.log10(amplitude)


def validate_file(path: Path, peak_ceiling_db: float) -> tuple[str, list[str]]:
    errors: list[str] = []
    try:
        with wave.open(str(path), "rb") as audio:
            channel_count = audio.getnchannels()
            sample_width = audio.getsampwidth()
            sample_rate = audio.getframerate()
            frame_count = audio.getnframes()
            frames = audio.readframes(frame_count)
    except (OSError, wave.Error) as error:
        return "", [f"{path}: unreadable WAV ({error})"]

    if channel_count != 1:
        errors.append(f"{path}: expected mono audio, got {channel_count} channels")
    if sample_width != 2:
        errors.append(f"{path}: expected PCM-16, got {sample_width * 8}-bit samples")
    if sample_rate != 44_100:
        errors.append(f"{path}: expected 44100 Hz, got {sample_rate} Hz")
    if frame_count == 0:
        errors.append(f"{path}: contains no audio frames")
        return hashlib.sha256(frames).hexdigest(), errors
    if sample_width != 2:
        return hashlib.sha256(frames).hexdigest(), errors

    samples = [sample[0] for sample in struct.iter_unpack("<h", frames)]
    peak = max(abs(sample) for sample in samples) / 32_768.0
    peak_db = amplitude_to_db(peak)
    if peak_db > peak_ceiling_db + 0.05:
        errors.append(
            f"{path}: peak {peak_db:.2f} dBFS exceeds {peak_ceiling_db:.2f} dBFS"
        )

    duration = frame_count / sample_rate
    if not 0.08 <= duration <= 1.5:
        errors.append(f"{path}: duration {duration:.3f}s is outside 0.08...1.50s")

    edge_limit = 32
    if abs(samples[0]) > edge_limit or abs(samples[-1]) > edge_limit:
        errors.append(
            f"{path}: boundary samples are not faded "
            f"({samples[0]}, {samples[-1]})"
        )
    return hashlib.sha256(frames).hexdigest(), errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--expected-count", type=int)
    parser.add_argument("--peak-ceiling-db", type=float, default=-10.0)
    args = parser.parse_args()

    files: list[Path] = []
    for path in args.paths:
        if path.is_dir():
            files.extend(sorted(path.glob("*.wav")))
        elif path.suffix.lower() == ".wav":
            files.append(path)

    errors: list[str] = []
    if args.expected_count is not None and len(files) != args.expected_count:
        errors.append(f"expected {args.expected_count} WAV files, found {len(files)}")

    digests: dict[str, Path] = {}
    for path in files:
        digest, file_errors = validate_file(path, args.peak_ceiling_db)
        errors.extend(file_errors)
        if digest in digests:
            errors.append(f"{path}: duplicates {digests[digest]}")
        elif digest:
            digests[digest] = path

    if errors:
        print("\n".join(f"error: {error}" for error in errors), file=sys.stderr)
        return 1

    print(
        f"Validated {len(files)} unique WAV files "
        f"at or below {args.peak_ceiling_db:.2f} dBFS."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
