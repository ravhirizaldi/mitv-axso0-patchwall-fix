#!/usr/bin/env bash
# Force com.quasartv.launcher as the default HOME activity and verify it.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"

adb -s "$SERIAL" wait-for-device
adb -s "$SERIAL" shell "cmd package set-home-activity --user 0 com.quasartv.launcher/.MainActivity"

resolved=$(adb -s "$SERIAL" shell \
  "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME" \
  | tr -d '\r' | tail -1)

echo "HOME: $resolved"
case "$resolved" in
  com.quasartv.launcher/*) ;;
  *)
    echo "ERROR: HOME is not Quasar" >&2
    exit 1
    ;;
esac
