#!/usr/bin/env bash
# Install or update the bundled Quasar launcher APK.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"

APK="$DIR/quasar-release.apk"
if [ ! -f "$APK" ]; then
  echo "ERROR: missing $APK" >&2
  exit 1
fi

adb -s "$SERIAL" wait-for-device
adb -s "$SERIAL" install -r "$APK"
