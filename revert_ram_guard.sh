#!/usr/bin/env bash
# Restore components and AppOps changed by apply_ram_guard.sh.
# Force-stop state clears when the app is launched; no manual restart is needed.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"

packages=(
  com.apple.atve.androidtv.appletv
  com.android.vending
  com.mitv.tvhome.atv
  in.startv.hotstar.dplus.tv
  com.wbd.stream
  com.netflix.ninja
  com.amazon.amazonvideo.livingroom
)

components=(
  com.mitv.tvhome.atv/com.mitv.tvhome.atv.app.BootCompletedReceiver
  com.netflix.ninja/com.netflix.ninja.BootCompleteReceiver
  com.apple.atve.androidtv.appletv/com.apple.atve.generic.LunaChannelNotificationReceiver
  com.amazon.amazonvideo.livingroom/com.amazon.ignitionshared.receiver.BootUpReceiver
  com.android.vending/com.google.android.finsky.boothandler.BootCompletedReceiver
  com.wbd.stream/com.wbd.beam.BootReceiver
  in.startv.hotstar.dplus.tv/com.hotstar.feature.engagement.receiver.BootupReceiver
  com.apple.atve.androidtv.appletv/androidx.work.impl.background.systemalarm.RescheduleReceiver
  com.android.vending/androidx.work.impl.background.systemalarm.RescheduleReceiver
  com.mitv.tvhome.atv/androidx.work.impl.background.systemalarm.RescheduleReceiver
  in.startv.hotstar.dplus.tv/androidx.work.impl.background.systemalarm.RescheduleReceiver
  com.netflix.ninja/androidx.work.impl.background.systemalarm.RescheduleReceiver
  com.amazon.amazonvideo.livingroom/androidx.work.impl.background.systemalarm.RescheduleReceiver
)

adb -s "$SERIAL" wait-for-device

echo "[1/2] restore components"
for c in "${components[@]}"; do
  adb -s "$SERIAL" shell "service call TvService 3 s16 'cmd package default-state --user 0 $c'" >/dev/null
done

echo "[2/2] restore appops"
for p in "${packages[@]}"; do
  adb -s "$SERIAL" shell "cmd appops set $p RUN_IN_BACKGROUND default"
  adb -s "$SERIAL" shell "cmd appops set $p RUN_ANY_IN_BACKGROUND default"
done

echo "Restored. Apps remain force-stopped until their next launch."
