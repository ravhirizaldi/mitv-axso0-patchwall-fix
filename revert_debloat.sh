#!/usr/bin/env bash
# Restore PatchWall components disabled by apply_debloat.sh.
# default-state returns each component to its manifest default (enabled).
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
  adb -s "$SERIAL" shell "service call TvService 3 s16 'cmd package default-state --user 0 $PKG/$c'" >/dev/null
done

echo "Restored:"
adb -s "$SERIAL" shell "dumpsys package $PKG | grep -A20 disabledComponents | head -24" || true
