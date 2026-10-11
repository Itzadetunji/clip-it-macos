#!/bin/zsh
# Builds clipit.dmg from Builds/ClipIt.app using appdmg.json, then gives the .dmg file the ClipIt icon.
set -euo pipefail

cd "$(dirname "$0")"

# Stale ClipIt volumes make Finder show old windows and shift the new one to "ClipIt 1", "ClipIt 2", ...
for volume in /Volumes/ClipIt*(N); do
    hdiutil detach "$volume" -force >/dev/null 2>&1 || true
done

rm -f clipit.dmg
bunx appdmg appdmg.json clipit.dmg

# appdmg only sets the mounted volume's icon; the .dmg file's own icon is a separate custom icon.
osascript -l JavaScript -e '
ObjC.import("AppKit");
const dir = $.NSFileManager.defaultManager.currentDirectoryPath.js;
const icon = $.NSImage.alloc.initWithContentsOfFile(dir + "/Builds/VolumeIcon.icns");
if (!$.NSWorkspace.sharedWorkspace.setIconForFileOptions(icon, dir + "/clipit.dmg", 0)) {
    throw new Error("Could not set the dmg icon");
}
' >/dev/null

echo "Created $(pwd)/clipit.dmg"
