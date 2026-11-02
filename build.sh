#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p build
# Reuse generated icons until their drawing source changes.
if [[ ! -f Assets/Khord.icns || ! -f Assets/Khord-AppIcon.png || ! -f Assets/Khord-Icons-Preview.png ||
      ! -f Assets/MenuBar.png || ! -f Assets/MenuBar@2x.png ||
      Sources/IconDrawing.swift -nt Assets/Khord.icns || Assets/GenerateIcons.swift -nt Assets/Khord.icns ]]; then
  xcrun swiftc -swift-version 5 -warnings-as-errors -module-cache-path "$PWD/build/ModuleCache" Sources/IconDrawing.swift Assets/GenerateIcons.swift -o build/generate-icons -framework AppKit
  build/generate-icons "$PWD/Assets"
fi

# A failed build/signature check must leave the previous app usable.
stage_dir="$(mktemp -d "$PWD/build/.stage.XXXXXX")"
trap 'rm -rf -- "$stage_dir"' EXIT
APP="$stage_dir/Khord.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Assets/Khord.icns "$APP/Contents/Resources/AppIcon.icns"
xcrun swiftc -module-cache-path "$PWD/build/ModuleCache" -swift-version 5 -warnings-as-errors -target "$(uname -m)-apple-macosx13.0" -O Sources/*.swift -o "$APP/Contents/MacOS/Khord" -framework AppKit -framework ApplicationServices -framework ServiceManagement
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.superduper.native</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleDisplayName</key><string>Khord</string>
<key>CFBundleName</key><string>Khord</string>
<key>CFBundleExecutable</key><string>Khord</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>36</string>
<key>CFBundleShortVersionString</key><string>1.17.6</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
plutil -lint "$APP/Contents/Info.plist" > /dev/null
if [[ -d build/Khord.app ]]; then
  rm -rf -- build/Khord.previous.app
  mv build/Khord.app build/Khord.previous.app
fi
mv "$APP" build/Khord.app
echo "Built: $PWD/build/Khord.app"
