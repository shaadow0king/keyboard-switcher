#!/bin/bash
# Publishes a new version as a GitHub release: ./release.sh 0.2
# Sets the version, runs the tests, builds a universal app (Apple Silicon + Intel) signed with Developer ID,
# has Apple notarize it, staples the ticket, checks Gatekeeper accepts it, packs it into a signed and notarized
# disk image (tools/make-dmg.sh: drag Mistype to Applications), and creates release v<version> with Mistype.dmg in
# the repository named in Info.plist (MistypeUpdatesRepo). Asks before publishing anything.
#
# One-time setup on this Mac:
#   - a "Developer ID Application" certificate in the keychain (Xcode → Settings → Accounts → Manage Certificates);
#   - notary credentials: xcrun notarytool store-credentials mistype-notary --apple-id … --team-id …
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>, e.g. 0.2}"
REPO=$(/usr/libexec/PlistBuddy -c "Print :MistypeUpdatesRepo" Info.plist)
[ -n "$REPO" ] || { echo "Set MistypeUpdatesRepo in Info.plist first (owner/name of a public repository)."; exit 1; }
DEVELOPER_ID=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ { print $2; exit }')
[ -n "$DEVELOPER_ID" ] || { echo "No Developer ID Application certificate in the keychain."; exit 1; }
NOTARY_PROFILE="${NOTARY_PROFILE:-mistype-notary}"

BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" Info.plist

swift test
UNIVERSAL=1 SIGN_IDENTITY="$DEVELOPER_ID" CODESIGN_FLAGS="--options runtime --timestamp" ./build.sh

ZIP="build/Mistype.zip"   # only for notarizing the app; people download the disk image
rm -f "$ZIP"
ditto -c -k --keepParent build/Mistype.app "$ZIP"
echo "Sending to Apple for notarization (usually a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple build/Mistype.app
spctl --assess --type execute -vv build/Mistype.app   # fails the script if Gatekeeper would still refuse it
rm -f "$ZIP"

# Always the same file name, so .../releases/latest/download/Mistype.dmg (the site's Download button) is the newest build.
tools/make-dmg.sh build/Mistype.app "$DEVELOPER_ID" "$NOTARY_PROFILE"
DMG=build/Mistype.dmg

read -r -p "Publish v$VERSION ($DMG) as a release in $REPO? [y/N] " answer
[ "$answer" = "y" ] || { echo "Not published. The version change in Info.plist is kept."; exit 0; }
gh release create "v$VERSION" "$DMG" --repo "$REPO" --title "Mistype $VERSION" --generate-notes
echo "Published. Mistype checks for it within a day, or at once with Settings → About → Check Now."
echo "Run ./build.sh afterwards to go back to your development build."
