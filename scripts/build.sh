#!/bin/bash
set -e

APP_NAME="LocalPorts"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ICON_SRC_DIR="Sources/LocalPorts/Resources/Assets.xcassets/AppIcon.appiconset"

echo "Building $APP_NAME (release, universal: arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64

BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy SwiftPM resources bundle if it exists (xcassets, etc.)
RESOURCES_BUNDLE="$BIN_PATH/LocalPorts_LocalPorts.bundle"
if [ -d "$RESOURCES_BUNDLE" ]; then
    cp -R "$RESOURCES_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

# Build AppIcon.icns from the iconset PNGs in xcassets (for Finder/Spotlight).
if [ -f "$ICON_SRC_DIR/icon_1024.png" ]; then
    echo "Building AppIcon.icns from $ICON_SRC_DIR..."
    ICONSET=$(mktemp -d)/AppIcon.iconset
    mkdir -p "$ICONSET"
    cp "$ICON_SRC_DIR/icon_16.png"    "$ICONSET/icon_16x16.png"
    cp "$ICON_SRC_DIR/icon_32.png"    "$ICONSET/icon_16x16@2x.png"
    cp "$ICON_SRC_DIR/icon_32.png"    "$ICONSET/icon_32x32.png"
    cp "$ICON_SRC_DIR/icon_32@2x.png" "$ICONSET/icon_32x32@2x.png"
    cp "$ICON_SRC_DIR/icon_128.png"   "$ICONSET/icon_128x128.png"
    cp "$ICON_SRC_DIR/icon_256.png"   "$ICONSET/icon_128x128@2x.png"
    cp "$ICON_SRC_DIR/icon_256.png"   "$ICONSET/icon_256x256.png"
    cp "$ICON_SRC_DIR/icon_512.png"   "$ICONSET/icon_256x256@2x.png"
    cp "$ICON_SRC_DIR/icon_512.png"   "$ICONSET/icon_512x512.png"
    cp "$ICON_SRC_DIR/icon_1024.png"  "$ICONSET/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$(dirname "$ICONSET")"
    ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
    echo "No icon source at $ICON_SRC_DIR; bundle will have no icon."
    ICON_KEY=""
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
    <string>1.1.3</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.3</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    $ICON_KEY
</dict>
</plist>
PLIST

echo ""
echo "Built successfully: $APP_BUNDLE"
echo "To install: cp -R $APP_BUNDLE /Applications/"
