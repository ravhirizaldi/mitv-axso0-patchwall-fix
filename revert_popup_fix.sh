#!/usr/bin/env bash
# Remove the dummy TV+ package used to suppress the PatchWall install popup.
# After this, the popup can return on the next TV+ promo banner. If you want the
# real Xiaomi TV+ later, this must be run first (the dummy is signed with a
# different key and would block the real APK as a signature mismatch).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"
PKG="com.mitv.tvhome.mitvplus"

adb -s "$SERIAL" uninstall "$PKG"
echo "Removed $PKG."
