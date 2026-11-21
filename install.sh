#!/bin/bash
# UsageBar installer: downloads the latest release and installs it to /Applications.
set -euo pipefail

URL="https://github.com/blueblud7/usage-bar/releases/latest/download/UsageBar.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading UsageBar..."
curl -fsSL "$URL" -o "$TMP/UsageBar.zip"
ditto -x -k "$TMP/UsageBar.zip" "$TMP"

DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

pkill -x UsageBar 2>/dev/null || true
rm -rf "$DEST/UsageBar.app"
cp -R "$TMP/UsageBar.app" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/UsageBar.app" 2>/dev/null || true

echo "Installed to $DEST/UsageBar.app"
open "$DEST/UsageBar.app"
