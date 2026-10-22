#!/bin/bash
# Builds build/Mistype.dmg: a window with Mistype on the left and Applications on the right, on a background
# that says to drag one onto the other. Signs the image with Developer ID, notarizes and staples it.
# Usage: tools/make-dmg.sh <path to Mistype.app> <Developer ID identity> <notary keychain profile>
# Lays the window out through Finder, so macOS may ask once to let the terminal control Finder.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$1"; IDENTITY="$2"; PROFILE="$3"
OUT=build/Mistype.dmg
STAGE=build/dmg-stage
RW=build/Mistype-rw.dmg

rm -rf "$STAGE" "$RW" "$OUT"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
swift tools/dmg-background.swift build/dmg-bg.png 1 >/dev/null
swift tools/dmg-background.swift build/dmg-bg@2x.png 2 >/dev/null
tiffutil -cathidpicheck build/dmg-bg.png build/dmg-bg@2x.png -out "$STAGE/.background/background.tiff" >/dev/null

hdiutil create -srcfolder "$STAGE" -volname Mistype -fs HFS+ -format UDRW -ov "$RW" >/dev/null
MOUNT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\// { print $NF }')
DISK=$(basename "$MOUNT")   # "Mistype", or "Mistype 1" if another Mistype image is open
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$DISK"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 548}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "Mistype.app" of container window to {160, 190}
    set position of item "Applications" of container window to {480, 190}
    update without registering applications
    delay 1
    close
    -- Finder keeps the window size only if it's set again on a reopened window
    open
    delay 1
    set the bounds of container window to {200, 120, 840, 548}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT
# Detach only after Finder has written the window settings
for _ in $(seq 1 20); do [ -f "$MOUNT/.DS_Store" ] && break; sleep 0.5; done
sleep 2
sync
hdiutil detach "$MOUNT" >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -ov -o "$OUT" >/dev/null
rm -f "$RW"; rm -rf "$STAGE"

codesign --force --sign "$IDENTITY" --timestamp "$OUT"
echo "Sending the disk image to Apple for notarization…"
xcrun notarytool submit "$OUT" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$OUT"
spctl --assess --type open --context context:primary-signature -vv "$OUT"
echo "Built $OUT"
