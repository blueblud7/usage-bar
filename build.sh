#!/bin/bash
set -e
cd "$(dirname "$0")"
APP=UsageBar.app
rm -rf "$APP" UsageBar.zip
mkdir -p "$APP/Contents/MacOS"
swiftc -O -target arm64-apple-macos13 Sources/UsageBar.swift -o /tmp/ub-arm
swiftc -O -target x86_64-apple-macos13 Sources/UsageBar.swift -o /tmp/ub-x86
lipo -create /tmp/ub-arm /tmp/ub-x86 -output "$APP/Contents/MacOS/UsageBar"
cat > "$APP/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>UsageBar</string>
<key>CFBundleDisplayName</key><string>UsageBar</string>
<key>CFBundleIdentifier</key><string>com.usagebar.app</string>
<key>CFBundleExecutable</key><string>UsageBar</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PL
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" UsageBar.zip
echo "built: $APP, UsageBar.zip"
