#!/usr/bin/env bash
# Ensure every package in disabled_packages.txt is disabled for user 0.
# All are system packages except the TV+ stub, so disable-user is sent through
# TvService (uid 1000); ordinary shell pm disable-user is refused for system apps.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"
LIST="$DIR/disabled_packages.txt"

adb -s "$SERIAL" wait-for-device
installed=$(adb -s "$SERIAL" shell pm list packages | tr -d '\r')
mapfile -t packages < <(grep -vE '^[[:space:]]*(#|$)' "$LIST")

for p in "${packages[@]}"; do
  if printf '%s\n' "$installed" | grep -qx "package:$p"; then
    adb -s "$SERIAL" shell "service call TvService 3 s16 'cmd package disable-user --user 0 $p'" >/dev/null </dev/null
    echo "disabled $p"
  else
    echo "skip (not installed): $p"
  fi
done

echo
echo "Disabled packages:"
adb -s "$SERIAL" shell "pm list packages -d" | tr -d '\r' | sort
