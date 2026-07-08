#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release

APP_DIR="$ROOT_DIR/.build/SquishMac.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/SquishMac" "$MACOS_DIR/SquishMac"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

RESOURCE_BUNDLE="$(find "$ROOT_DIR/.build" -name 'SquishMac_SquishMac.bundle' -type d | head -n 1 || true)"
if [[ -n "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

chmod +x "$MACOS_DIR/SquishMac"
echo "Built $APP_DIR"
