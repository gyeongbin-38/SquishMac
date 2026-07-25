#!/usr/bin/env python3
"""Serve the SquishMac reference preview and open it in the default browser."""

from __future__ import annotations

import argparse
import functools
import http.server
import socket
import sys
import threading
import urllib.parse
import webbrowser
from pathlib import Path


class PreviewRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Ignore browser disconnects while it abandons a streaming video request."""

    def copyfile(self, source: object, outputfile: object) -> None:
        try:
            super().copyfile(source, outputfile)
        except (BrokenPipeError, ConnectionResetError):
            pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dataset",
        default="AnalysisOutput/1",
        help="Dataset directory relative to the repository root.",
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-open", action="store_true", help="Do not open a browser.")
    return parser.parse_args()


def find_available_port(host: str, preferred_port: int) -> int:
    for port in range(preferred_port, preferred_port + 20):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            try:
                probe.bind((host, port))
            except OSError:
                continue
            return port
    raise RuntimeError("No available preview port found.")


def validate_dataset(repo_root: Path, dataset_argument: str) -> str:
    dataset_path = (repo_root / dataset_argument).resolve()
    try:
        dataset_path.relative_to(repo_root)
    except ValueError as error:
        raise ValueError("Dataset must be inside the repository.") from error

    manifest = dataset_path / "dataset.json"
    if not manifest.is_file():
        raise FileNotFoundError(f"Dataset manifest not found: {manifest}")
    return dataset_path.relative_to(repo_root).as_posix()


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parent.parent

    try:
        dataset = validate_dataset(repo_root, args.dataset)
        port = find_available_port(args.host, args.port)
    except (FileNotFoundError, RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    handler = functools.partial(
        PreviewRequestHandler,
        directory=str(repo_root),
    )
    server = http.server.ThreadingHTTPServer((args.host, port), handler)
    query = urllib.parse.urlencode({"dataset": f"/{dataset}"})
    url = f"http://{args.host}:{port}/Tools/reference_preview/index.html?{query}"

    print(f"SquishMac Reference Lab: {url}", flush=True)
    print("Press Ctrl+C to stop the server.", flush=True)

    if not args.no_open:
        threading.Timer(0.4, webbrowser.open, args=(url,)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping preview server.", flush=True)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
