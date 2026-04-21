#!/bin/bash
set -e

# UsageDeck — build and run
# Usage: ./Scripts/compile_and_run.sh [debug|release]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

BUILD_CONFIG="${1:-debug}"
APP_NAME="UsageDeck"
BUNDLE_NAME="Usage Deck"
BUNDLE_ID="com.usagedeck.app"

echo "→ Stopping existing instances..."
pkill -x "$APP_NAME" 2>/dev/null || true
pkill -f "$APP_NAME.app" 2>/dev/null || true
pkill -f "$BUNDLE_NAME.app" 2>/dev/null || true
sleep 0.5

echo "→ Building ($BUILD_CONFIG)..."
if [ "$BUILD_CONFIG" = "release" ]; then
    swift build -c release
    BUILD_PATH=".build/release"
else
    swift build
    BUILD_PATH=".build/debug"
fi

echo "→ Creating app bundle..."
APP_BUNDLE="$PROJECT_DIR/$BUNDLE_NAME.app"
# Clean up the legacy no-space bundle if it exists.
rm -rf "$PROJECT_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

for bundle in "$BUILD_PATH"/*.bundle; do
    if [ -d "$bundle" ]; then
        echo "→ Copying resource bundle: $(basename "$bundle")"
        cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
    fi
done

cp "$PROJECT_DIR/Sources/UsageDeck/Plist/Info.plist" "$APP_BUNDLE/Contents/"

if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    echo "→ Copying app icon..."
    cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "→ Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "→ Launching..."
open -n "$APP_BUNDLE"

sleep 1
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "✓ $APP_NAME is running — check the menu bar."
else
    echo "✗ Failed to launch $APP_NAME — check Console.app."
    exit 1
fi
