#!/usr/bin/env bash
# Stop the PatchWall "Xiaomi TV+ / Instal apl ini?" popup without root or APK changes.
#
# Mechanism: PatchWall checks whether com.mitv.tvhome.mitvplus is installed and
# compares its versionCode against the banner's target version before starting
# DownloadTipsActivity. A dummy package with a very high versionCode satisfies
# that check. The package is then disabled so TvPlusRedirectHelper still sees
# TV+ as unavailable and does not switch the launcher. The autoplay's
# mitvplus:// launch then fails inside a caught ActivityNotFoundException.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"
PKG="com.mitv.tvhome.mitvplus"

adb -s "$SERIAL" wait-for-device

if adb -s "$SERIAL" shell pm path "$PKG" 2>/dev/null | grep -q '^package:'; then
  if ! adb -s "$SERIAL" shell dumpsys package "$PKG" 2>/dev/null | grep -q 'versionName=999'; then
    echo "A different $PKG is already installed; not modifying it."
    echo "If it is the real Xiaomi TV+, the popup should already be gone."
    exit 1
  fi
fi

adb -s "$SERIAL" install -r "$DIR/stub-tvplus.apk"
adb -s "$SERIAL" shell pm disable-user --user 0 "$PKG"
adb -s "$SERIAL" shell dumpsys package "$PKG" | grep -E 'versionCode|enabled='

echo
echo "Applied. Force-stop PatchWall to test:"
echo "  adb -s $SERIAL shell am force-stop com.mitv.tvhome.atv"
echo "  adb -s $SERIAL shell am start -n com.mitv.tvhome.atv/.app.PatchWallActivity"
