#!/bin/bash
set -euo pipefail

PROJECT_DIR="/Users/robertwang/Develop/gmail-client"
APP_NAME="CGmail"
SCHEME="CGmail"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$PROJECT_DIR/dist"
VERSION=$(date +"%Y%m%d_%H%M%S")
DMG_NAME="${APP_NAME}_${VERSION}.dmg"

# Only build DMG if the last xcodebuild was a "build" (not test/archive/etc)
# and succeeded
echo "[DMG] Starting DMG build for $APP_NAME..."

# Step 1: Build the app (release config, no signing for local use)
echo "[DMG] Building app bundle..."
xcodebuild build \
  -scheme "$SCHEME" \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release" \
  2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | tail -5

APP_PATH="$BUILD_DIR/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
  echo "[DMG] ERROR: App bundle not found at $APP_PATH"
  exit 1
fi

echo "[DMG] App built: $APP_PATH"

# Step 2: Create staging directory
STAGING_DIR="$(mktemp -d)"
cp -R "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Step 3: Create DMG with hdiutil
mkdir -p "$DMG_DIR"
DMG_PATH="$DMG_DIR/$DMG_NAME"
LATEST_DMG="$DMG_DIR/${APP_NAME}_latest.dmg"

echo "[DMG] Creating DMG at $DMG_PATH..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  2>&1 | tail -3

# Also update "latest" symlink
ln -sf "$DMG_PATH" "$LATEST_DMG"

# Cleanup
rm -rf "$STAGING_DIR"

echo "[DMG] ✓ Done: $DMG_PATH"
echo "[DMG] ✓ Latest: $LATEST_DMG"
