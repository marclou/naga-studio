#!/usr/bin/env bash
# Builds a universal "Naga Studio.app" into build/.
#   --install  copy it to /Applications and launch it
#   --zip      also package build/Naga-Studio-<version>.zip for a GitHub release
# The app is ad-hoc signed by default. Set SIGN_IDENTITY to your own certificate
# (for example "Apple Development") so macOS keeps its permissions across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Naga Studio"
EXECUTABLE="NagaStudio"
APP_DIR="build/$APP_NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" resources/Info.plist)

# One build per architecture, merged with lipo: `swift build --arch arm64 --arch x86_64` can deadlock in Xcode 26.
binaries=()
for arch in arm64 x86_64; do
  swift build -c release --arch "$arch"
  binaries+=("$(swift build -c release --arch "$arch" --show-bin-path)/$EXECUTABLE")
done

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources/fonts"
lipo -create -output "$APP_DIR/Contents/MacOS/$EXECUTABLE" "${binaries[@]}"
# Drops the debug map, which records absolute build paths.
strip -S -x "$APP_DIR/Contents/MacOS/$EXECUTABLE"
cp resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp resources/fonts/*.ttf resources/fonts/OFL.txt "$APP_DIR/Contents/Resources/fonts/"
cp resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR"
echo "Built $APP_DIR ($VERSION)"

for argument in "$@"; do
  case "$argument" in
    --zip)
      ZIP="build/Naga-Studio-$VERSION.zip"
      rm -f "$ZIP"
      ditto -c -k --norsrc --noextattr --keepParent "$APP_DIR" "$ZIP"
      echo "Packaged $ZIP"
      ;;
    --install)
      pkill -x "$EXECUTABLE" 2>/dev/null || true
      # Opening again before the old copy has fully quit fails with LaunchServices error -600.
      for _ in {1..50}; do pgrep -x "$EXECUTABLE" >/dev/null || break; sleep 0.1; done
      rm -rf "/Applications/$APP_NAME.app"
      cp -R "$APP_DIR" "/Applications/"
      open "/Applications/$APP_NAME.app"
      echo "Installed to /Applications/$APP_NAME.app"
      ;;
  esac
done
