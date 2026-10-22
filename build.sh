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

# The dev identity is remembered in .sign-identity (not committed): switching certificates makes macOS drop the grant.
# A SIGN_IDENTITY passed in (release.sh) is used for this build only and never replaces it.
if [ -z "${SIGN_IDENTITY:-}" ]; then
  [ -f .sign-identity ] || security find-identity -v -p codesigning | awk '/Apple Development/ { print $2; exit }' > .sign-identity
  SIGN_IDENTITY="$(cat .sign-identity)"
fi
# shellcheck disable=SC2086  # CODESIGN_FLAGS is a list of flags
codesign --force ${CODESIGN_FLAGS:-} --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Mistype")), signed with: ${SIGN_IDENTITY:-ad-hoc}"
