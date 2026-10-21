#!/usr/bin/env bash
# Force the self-made Quasar launcher (com.quasartv.launcher) as default HOME and verify it.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"

adb -s "$SERIAL" wait-for-device

installed_path=$(adb -s "$SERIAL" shell pm path com.quasartv.launcher 2>/dev/null | tr -d '\r' || true)
case "$installed_path" in
  package:*)
    echo "Quasar is installed: $installed_path"
    ;;
  *)
    if [ ! -f "$DIR/quasar-release.apk" ]; then
      echo "ERROR: Quasar is not installed and $DIR/quasar-release.apk is missing" >&2
      exit 1
    fi
    echo "Quasar is not installed; installing bundled quasar-release.apk..."
    adb -s "$SERIAL" install -r "$DIR/quasar-release.apk"
    ;;
esac

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
