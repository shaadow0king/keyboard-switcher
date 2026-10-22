#!/bin/bash
# Builds build/Mistype.app and signs it with your Apple Development certificate,
# so macOS keeps the Accessibility grant across rebuilds. Override with SIGN_IDENTITY=...
# release.sh sets UNIVERSAL=1 (Apple Silicon + Intel) and CODESIGN_FLAGS for a Developer ID build.
set -euo pipefail
cd "$(dirname "$0")"

ARCH_FLAGS=()
[ "${UNIVERSAL:-}" = 1 ] && ARCH_FLAGS=(--arch arm64 --arch x86_64)
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Mistype"

APP=build/Mistype.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Sparkle (in-app updates). Mistype isn't sandboxed, so Sparkle's XPC services aren't needed (Sparkle's docs say they
# can go): fewer parts to sign.
FW=.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework
mkdir -p "$APP/Contents/Frameworks"
ditto "$FW" "$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$APP/Contents/Frameworks/Sparkle.framework/XPCServices"

# The dev identity is remembered in .sign-identity (not committed): switching certificates makes macOS drop the grant.
# A SIGN_IDENTITY passed in (release.sh) is used for this build only and never replaces it.
if [ -z "${SIGN_IDENTITY:-}" ]; then
  [ -f .sign-identity ] || security find-identity -v -p codesigning | awk '/Apple Development/ { print $2; exit }' > .sign-identity
  SIGN_IDENTITY="$(cat .sign-identity)"
fi
# Inside out: Sparkle's helpers, the framework, then the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
for part in "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE" "$APP"; do
  # shellcheck disable=SC2086  # CODESIGN_FLAGS is a list of flags
  codesign --force ${CODESIGN_FLAGS:-} --sign "${SIGN_IDENTITY:--}" "$part"
done
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Mistype")), signed with: ${SIGN_IDENTITY:-ad-hoc}"
