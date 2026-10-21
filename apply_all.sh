#!/usr/bin/env bash
# Reapply the full MiTV-AXSO0 setup in order.
# Quasar install (if missing) + HOME -> TV+ stub -> disabled packages -> PatchWall debloat -> RAM guard.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"

"$DIR/ensure_quasar_home.sh"
"$DIR/apply_popup_fix.sh"
"$DIR/apply_disabled_packages.sh"
"$DIR/apply_debloat.sh"
"$DIR/apply_ram_guard.sh"

echo "All applied."
