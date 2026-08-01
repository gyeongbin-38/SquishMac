#!/usr/bin/env python3
"""Smoke tests for the SquishMac cross-platform functional-test server."""

from __future__ import annotations

import functools
import http.server
import json
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

from functional_test_server import FunctionalTestRequestHandler


class QuietFunctionalTestRequestHandler(FunctionalTestRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        pass


class FunctionalTestServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repo_root = Path(__file__).resolve().parent.parent
        app_root = cls.repo_root / "Tools" / "functional_test"
        sounds_root = (
            cls.repo_root / "Sources" / "SquishMac" / "Resources" / "Sounds"
        )
        handler = functools.partial(
            QuietFunctionalTestRequestHandler,
            sounds_root=sounds_root.resolve(),
            directory=str(app_root.resolve()),
        )
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        cls.server_thread = threading.Thread(
            target=cls.server.serve_forever,
            daemon=True,
        )
        cls.server_thread.start()
        host, port = cls.server.server_address
        cls.base_url = f"http://{host}:{port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.server_thread.join(timeout=2)

    def fetch(self, path: str) -> tuple[bytes, str]:
        with urllib.request.urlopen(f"{self.base_url}{path}", timeout=3) as response:
            return response.read(), response.headers.get_content_type()

    def test_health_and_sound_manifest(self) -> None:
        health_data, health_type = self.fetch("/api/health")
        self.assertEqual(health_type, "application/json")
        self.assertEqual(json.loads(health_data), {"status": "ok"})

        manifest_data, manifest_type = self.fetch("/api/sound-packs")
        manifest = json.loads(manifest_data)["packs"]
        self.assertEqual(manifest_type, "application/json")
        self.assertGreaterEqual(len(manifest), 25)
        self.assertEqual(len(manifest["clear-video-3-knead"]), 34)
        self.assertGreaterEqual(
            sum(len(files) for files in manifest.values()),
            278,
        )

    def test_browser_modules_and_audio_use_playable_mime_types(self) -> None:
        index_data, index_type = self.fetch("/")
        app_data, app_type = self.fetch("/app.mjs")
        audio_data, audio_type = self.fetch("/sounds/bubble/bubble-1.wav")

        self.assertEqual(index_type, "text/html")
        self.assertIn(b'SquishMac Functional Test', index_data)
        self.assertEqual(app_type, "text/javascript")
        self.assertIn(b'from "./engine.mjs"', app_data)
        self.assertEqual(audio_type, "audio/wav")
        self.assertGreater(len(audio_data), 44)

    def test_paths_cannot_escape_the_served_roots(self) -> None:
        with self.assertRaises(urllib.error.HTTPError) as context:
            self.fetch("/sounds/%2e%2e/%2e%2e/README.md")
        self.assertEqual(context.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
