#!/bin/bash
# Builds build/Mistype.app and signs it with your Apple Development certificate,
# so macOS keeps the Accessibility grant across rebuilds. Override with SIGN_IDENTITY=...
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=build/Mistype.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Mistype "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

# The identity is remembered in .sign-identity (not committed): switching certificates makes macOS drop the grant.
[ -f .sign-identity ] && SIGN_IDENTITY="${SIGN_IDENTITY:-$(cat .sign-identity)}"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development/ { print $2; exit }')}"
[ -n "$IDENTITY" ] && echo "$IDENTITY" > .sign-identity
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP, signed with: ${IDENTITY:-ad-hoc}"
