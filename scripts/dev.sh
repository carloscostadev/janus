#!/bin/bash
set -e

APP_NAME="LocalPorts"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME (debug)..."
swift build

BIN_PATH=$(swift build --show-bin-path)

# Create .app bundle
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy resources bundle if it exists (asset catalogs)
RESOURCES="$BIN_PATH/LocalPorts_LocalPorts.bundle"
if [ -d "$RESOURCES" ]; then
    cp -R "$RESOURCES" "$APP_BUNDLE/Contents/Resources/"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.carloscosta.LocalPorts</string>
    <key>CFBundleVersion</key>
    <string>1.1.2</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.2</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST

# Kill running instance, install, relaunch
echo "Restarting $APP_NAME..."
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5
cp -R "$APP_BUNDLE" /Applications/
open "/Applications/$APP_NAME.app"

echo "Done! $APP_NAME is running."
