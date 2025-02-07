#!/bin/bash

# Create necessary directories if they don't exist
mkdir -p CapsLangSwitch.app/Contents/{MacOS,Resources}
mkdir -p iconset.iconset

# Create Info.plist if it doesn't exist
cat > CapsLangSwitch.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CapsLangSwitch</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.slava.CapsLangSwitch</string>
    <key>CFBundleName</key>
    <string>CapsLangSwitch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Compile the Swift file
swiftc CapsLangSwitch.swift \
    -o CapsLangSwitch.app/Contents/MacOS/CapsLangSwitch \
    -framework Cocoa \
    -framework Carbon

# Create icon in various sizes
sips -z 16 16     logo.png --out iconset.iconset/icon_16x16.png
sips -z 32 32     logo.png --out iconset.iconset/icon_16x16@2x.png
sips -z 32 32     logo.png --out iconset.iconset/icon_32x32.png
sips -z 64 64     logo.png --out iconset.iconset/icon_32x32@2x.png
sips -z 128 128   logo.png --out iconset.iconset/icon_128x128.png
sips -z 256 256   logo.png --out iconset.iconset/icon_128x128@2x.png
sips -z 256 256   logo.png --out iconset.iconset/icon_256x256.png
sips -z 512 512   logo.png --out iconset.iconset/icon_256x256@2x.png
sips -z 512 512   logo.png --out iconset.iconset/icon_512x512.png
sips -z 1024 1024 logo.png --out iconset.iconset/icon_512x512@2x.png

# Convert the iconset to icns
iconutil -c icns iconset.iconset -o CapsLangSwitch.app/Contents/Resources/AppIcon.icns

# Clean up
rm -rf iconset.iconset

# Make the binary executable
chmod +x CapsLangSwitch.app/Contents/MacOS/CapsLangSwitch

echo "Build complete. App is at ./CapsLangSwitch.app"