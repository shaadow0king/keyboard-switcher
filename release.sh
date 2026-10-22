#!/bin/bash
# Publishes a new version as a GitHub release: ./release.sh 0.2
# Sets the version, builds and signs the app, zips it, and creates release v<version> with the zip in the
# repository named in Info.plist (MistypeUpdatesRepo). That repository must be public, or people's
# Mistype can't see the release. Asks before publishing anything.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>, e.g. 0.2}"
REPO=$(/usr/libexec/PlistBuddy -c "Print :MistypeUpdatesRepo" Info.plist)
[ -n "$REPO" ] || { echo "Set MistypeUpdatesRepo in Info.plist first (owner/name of a public repository)."; exit 1; }

BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" Info.plist

swift test
./build.sh
ZIP="build/Mistype-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Mistype.app "$ZIP"

read -r -p "Publish v$VERSION ($ZIP) as a release in $REPO? [y/N] " answer
[ "$answer" = "y" ] || { echo "Not published. The version change in Info.plist is kept."; exit 0; }
gh release create "v$VERSION" "$ZIP" --repo "$REPO" --title "Mistype $VERSION" --generate-notes
echo "Published. Mistype checks for it within a day, or at once with Settings → About → Check Now."
