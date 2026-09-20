#!/bin/bash
# Builds a styled PrepPlanner.dmg: custom background, window size and icon positions.
#
# Usage: scripts/make_dmg.sh <path/to/PrepPlanner.app> <output.dmg>
set -euo pipefail

APP="${1:?path to PrepPlanner.app}"
OUT="${2:?output dmg path}"
VOLUME="PrepPlanner"
WORK="$(mktemp -d)"
STAGE="$WORK/stage"
TEMP_DMG="$WORK/temp.dmg"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

swiftc -O -o "$WORK/dmgbg" "$ROOT/scripts/make_dmg_background.swift"
"$WORK/dmgbg" "$STAGE/.background/background.png" >/dev/null

# Read-write image first, so Finder can store the window settings inside it.
hdiutil create -srcfolder "$STAGE" -volname "$VOLUME" -fs HFS+ \
    -format UDRW -ov "$TEMP_DMG" >/dev/null
MOUNT="/Volumes/$VOLUME"
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT" >/dev/null
sleep 2

osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {240, 140, 880, 580}
        set options to the icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 96
        set text size of options to 12
        set background picture of options to file ".background:background.png"
        set position of item "PrepPlanner.app" of container window to {160, 190}
        set position of item "Applications" of container window to {480, 190}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

sync
hdiutil detach "$MOUNT" >/dev/null
rm -f "$OUT"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -rf "$WORK"
echo "built $OUT"
