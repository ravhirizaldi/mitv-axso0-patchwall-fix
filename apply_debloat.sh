#!/usr/bin/env bash
# Disable PatchWall background/telemetry components without root.
#
# PatchWall is a system app, so ordinary `adb shell pm disable` is refused for
# its components. The TV's vendor service (TvService, transaction 3 =
# runSystemCommand) executes a command as uid 1000 (system). `cmd package` from
# that uid is allowed to change component state. This script uses that channel.
#
# What it stops:
#   - WorkManager JobScheduler / AlarmManager execution (background jobs)
#   - Firebase Analytics / Measurement components and FID receiver
#   - Firebase data-transport alarm receiver
#   - Skyeye stats receiver and log-analysis service
#
# It does NOT touch PatchWall's launcher activities, update dialog, ad video
# activity, or DownloadTipsActivity. Revert with revert_debloat.sh.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adb_select.sh
source "$DIR/adb_select.sh"
adb_select_device
SERIAL="$ADB_SERIAL"
PKG="com.mitv.tvhome.atv"

components=(
  "androidx.work.impl.background.systemjob.SystemJobService"
  "androidx.work.impl.background.systemalarm.SystemAlarmService"
  "com.google.android.gms.measurement.AppMeasurementReceiver"
  "com.google.android.gms.measurement.AppMeasurementService"
  "com.google.android.gms.measurement.AppMeasurementJobService"
  "com.google.android.gms.measurement.AppMeasurementInstallReferrerReceiver"
  "com.google.firebase.iid.FirebaseInstanceIdReceiver"
  "com.google.android.datatransport.runtime.scheduling.jobscheduling.AlarmManagerSchedulerBroadcastReceiver"
  "com.mitv.skyeye.SkyeyeStatReceiver"
  "com.mitv.skyeye.flowimpl.analyzer.LogAnalyzeService"
)

adb -s "$SERIAL" wait-for-device
for c in "${components[@]}"; do
  adb -s "$SERIAL" shell "service call TvService 3 s16 'cmd package disable --user 0 $PKG/$c'" >/dev/null
done

echo "Disabled:"
adb -s "$SERIAL" shell "dumpsys package $PKG | grep -A20 disabledComponents | head -24" || true
