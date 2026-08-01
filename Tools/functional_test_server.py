#!/usr/bin/env python3
"""Serve the cross-platform SquishMac functional test harness."""

from __future__ import annotations

import argparse
import functools
import http.server
import json
import socket
import sys
import threading
import urllib.parse
import webbrowser
from pathlib import Path, PurePosixPath


SUPPORTED_AUDIO_EXTENSIONS = {".wav", ".mp3", ".m4a", ".aiff", ".aif"}


class FunctionalTestRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Serve the harness plus read-only access to bundled sound files."""

    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".mjs": "text/javascript",
    }

    def __init__(
        self,
        *args: object,
        sounds_root: Path,
        directory: str,
        **kwargs: object,
    ) -> None:
        self.sounds_root = sounds_root
        super().__init__(*args, directory=directory, **kwargs)

    def do_GET(self) -> None:
        request_path = urllib.parse.urlsplit(self.path).path
        if request_path == "/api/health":
            self.send_json({"status": "ok"})
            return
        if request_path == "/api/sound-packs":
            self.send_json({"packs": self.sound_pack_manifest()})
            return
        super().do_GET()

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def translate_path(self, path: str) -> str:
        request_path = urllib.parse.unquote(urllib.parse.urlsplit(path).path)
        if not request_path.startswith("/sounds/"):
            return super().translate_path(path)

        parts = [
            part
            for part in PurePosixPath(request_path).parts[2:]
            if part not in {"", ".", ".."}
        ]
        candidate = self.sounds_root.joinpath(*parts).resolve()
        try:
            candidate.relative_to(self.sounds_root)
        except ValueError:
            return str(self.sounds_root / "__invalid_path__")
        return str(candidate)

    def sound_pack_manifest(self) -> dict[str, list[str]]:
        manifest: dict[str, list[str]] = {}
        for pack_directory in sorted(self.sounds_root.iterdir()):
            if not pack_directory.is_dir():
                continue
            files = [
                item
                for item in sorted(pack_directory.iterdir())
                if item.is_file() and item.suffix.lower() in SUPPORTED_AUDIO_EXTENSIONS
            ]
            manifest[pack_directory.name] = [
                "/sounds/"
                + urllib.parse.quote(pack_directory.name)
                + "/"
                + urllib.parse.quote(item.name)
                for item in files
            ]
        return manifest

    def send_json(self, payload: object) -> None:
        encoded = json.dumps(payload, ensure_ascii=True).encode("utf-8")
        self.send_response(http.HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def copyfile(self, source: object, outputfile: object) -> None:
        try:
            super().copyfile(source, outputfile)
        except (BrokenPipeError, ConnectionResetError):
            pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8775)
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
    raise RuntimeError("No available functional-test port found.")


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parent.parent
    app_root = repo_root / "Tools" / "functional_test"
    sounds_root = repo_root / "Sources" / "SquishMac" / "Resources" / "Sounds"

    if not (app_root / "index.html").is_file():
        print(f"error: functional test UI not found: {app_root}", file=sys.stderr)
        return 2
    if not sounds_root.is_dir():
        print(f"error: sound directory not found: {sounds_root}", file=sys.stderr)
        return 2

    try:
        port = find_available_port(args.host, args.port)
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    handler = functools.partial(
        FunctionalTestRequestHandler,
        sounds_root=sounds_root.resolve(),
        directory=str(app_root.resolve()),
    )
    server = http.server.ThreadingHTTPServer((args.host, port), handler)
    url = f"http://{args.host}:{port}/"

    print(f"SquishMac Functional Test: {url}", flush=True)
    print("Press Ctrl+C to stop the server.", flush=True)

    if not args.no_open:
        threading.Timer(0.4, webbrowser.open, args=(url,)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping functional test server.", flush=True)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
