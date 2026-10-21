#!/usr/bin/env bash
# Stop selected media/store apps, block background execution, and disable their
# BOOT_COMPLETED + WorkManager reschedule receivers so they do not auto-start
# after a reboot. The apps stay installed and can still be launched manually.
#
# Revert with revert_ram_guard.sh.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"

# Quasar is the default HOME. Enforce it and never add it to packages[].
"$DIR/ensure_quasar_home.sh"

packages=(
  # NOTE: com.quasartv.launcher is deliberately absent — it is the HOME app.
  com.apple.atve.androidtv.appletv
  com.android.vending
  com.mitv.tvhome.atv
  in.startv.hotstar.dplus.tv
  com.wbd.stream
  com.netflix.ninja
  com.amazon.amazonvideo.livingroom
)

components=(
  # App BOOT_COMPLETED receivers
  com.mitv.tvhome.atv/com.mitv.tvhome.atv.app.BootCompletedReceiver
  com.netflix.ninja/com.netflix.ninja.BootCompleteReceiver
  com.apple.atve.androidtv.appletv/com.apple.atve.generic.LunaChannelNotificationReceiver
  com.amazon.amazonvideo.livingroom/com.amazon.ignitionshared.receiver.BootUpReceiver
  com.android.vending/com.google.android.finsky.boothandler.BootCompletedReceiver
  com.wbd.stream/com.wbd.beam.BootReceiver
  in.startv.hotstar.dplus.tv/com.hotstar.feature.engagement.receiver.BootupReceiver
  # WorkManager boot reschedule receiver
  com.apple.atve.androidtv.appletv/androidx.work.impl.background.systemalarm.RescheduleReceiver
  com.android.vending/androidx.work.impl.background.systemalarm.RescheduleReceiver
  com.mitv.tvhome.atv/androidx.work.impl.background.systemalarm.RescheduleReceiver
  in.startv.hotstar.dplus.tv/androidx.work.impl.background.systemalarm.RescheduleReceiver
  com.netflix.ninja/androidx.work.impl.background.systemalarm.RescheduleReceiver
  com.amazon.amazonvideo.livingroom/androidx.work.impl.background.systemalarm.RescheduleReceiver
)

adb -s "$SERIAL" wait-for-device

echo "[1/3] force-stop"
for p in "${packages[@]}"; do
  adb -s "$SERIAL" shell "am force-stop $p"
done

echo "[2/3] appops background restriction"
for p in "${packages[@]}"; do
  adb -s "$SERIAL" shell "cmd appops set $p RUN_IN_BACKGROUND ignore"
  adb -s "$SERIAL" shell "cmd appops set $p RUN_ANY_IN_BACKGROUND ignore"
done

echo "[3/3] disable boot receivers (TvService uid 1000)"
for c in "${components[@]}"; do
  adb -s "$SERIAL" shell "service call TvService 3 s16 'cmd package disable --user 0 $c'" >/dev/null
done

echo "Done. Verify:"
for p in "${packages[@]}"; do
  printf '%-45s ' "$p"
  pids=$(adb -s "$SERIAL" shell "pidof $p" 2>/dev/null | tr -d '\r' || true)
  state=$(adb -s "$SERIAL" shell "dumpsys package $p" 2>/dev/null | tr -d '\r' | grep -m1 -o 'stopped=[a-z]*' || true)
  state=${state:-stopped=unknown}
  if [ -z "$pids" ]; then
    echo "$state, not running"
  else
    echo "$state, PID $pids"
  fi
done
