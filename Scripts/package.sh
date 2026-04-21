#!/bin/bash
set -euo pipefail

# Build a release .app bundle and package it as a ZIP for GitHub Releases.
# Usage: ./Scripts/package.sh [version]
#   version — optional, e.g. "1.0.0". Defaults to "dev".

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

VERSION="${1:-dev}"
APP_NAME="UsageDeck"
BUNDLE_NAME="Usage Deck"
BUNDLE_ID="com.usagedeck.app"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
ZIP_PATH="$DIST_DIR/UsageDeck-$VERSION.zip"

echo "→ Cleaning dist/"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "→ Building release"
swift build -c release

BUILD_PATH=".build/release"

echo "→ Assembling $BUNDLE_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

for bundle in "$BUILD_PATH"/*.bundle; do
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
    fi
done

cp "$PROJECT_DIR/Sources/UsageDeck/Plist/Info.plist" "$APP_BUNDLE/Contents/"

if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "→ Ad-hoc signing"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "→ Zipping to $ZIP_PATH"
# `ditto` preserves macOS extended attributes and resource forks — prefer it
# over `zip` for shipping .app bundles.
(cd "$DIST_DIR" && ditto -c -k --keepParent "$BUNDLE_NAME.app" "$(basename "$ZIP_PATH")")

SIZE=$(du -sh "$ZIP_PATH" | awk '{print $1}')
SHA=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "✓ Built: $ZIP_PATH ($SIZE)"
echo "  sha256: $SHA"
