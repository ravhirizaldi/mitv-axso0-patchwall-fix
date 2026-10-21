#!/usr/bin/env bash
# Shared interactive ADB device selector.
#
# Source this file, then call adb_select_device. The function:
#   - honors ADB_SERIAL when it points at an online device;
#   - auto-selects when exactly one online device is attached;
#   - shows a numbered menu when several are attached;
#   - prints a warning and waits for Enter when none are online.
#
# It exports ADB_SERIAL so child scripts (apply_all.sh) do not prompt again.

adb_select_device() {
  local devices_out="" serial state choice i
  local -a online=()
  local -a detected=()

  if ! command -v adb >/dev/null 2>&1; then
    printf '\nWARNING: adb is not installed or not in PATH.\n'
    printf 'Install Android platform-tools, then run this script again.\n\n'
    printf 'Press Enter to quit...'
    read -r _ || true
    printf '\n'
    exit 1
  fi

  if ! devices_out=$(adb devices 2>&1); then
    printf '\nWARNING: could not query ADB devices.\n%s\n\n' "$devices_out"
    printf 'Press Enter to quit...'
    read -r _ || true
    printf '\n'
    exit 1
  fi

  while IFS=$'\t' read -r serial state; do
    [ -z "$serial" ] && continue
    detected+=("$serial ($state)")
    [ "$state" = "device" ] && online+=("$serial")
  done < <(
    printf '%s\n' "$devices_out" |
      awk 'NF >= 2 && $2 ~ /^(device|offline|unauthorized|authorizing|recovery|sideload|bootloader)$/ {
             print $1 "\t" $2
           }'
  )

  if [ -n "${ADB_SERIAL:-}" ]; then
    for serial in "${online[@]}"; do
      if [ "$serial" = "$ADB_SERIAL" ]; then
        export ADB_SERIAL
        printf 'Using ADB device: %s\n' "$ADB_SERIAL"
        return 0
      fi
    done
    printf 'WARNING: ADB_SERIAL=%s is not an online device.\n' "$ADB_SERIAL"
  fi

  if [ "${#online[@]}" -eq 0 ]; then
    printf '\nWARNING: no online ADB device found.\n'
    if [ "${#detected[@]}" -gt 0 ]; then
      printf 'Detected:\n'
      printf '  %s\n' "${detected[@]}"
      printf 'Authorize the debugging prompt on the TV, then retry.\n'
    else
      printf 'Connect the TV over USB, or connect over the network first:\n'
      printf '  adb connect <TV-IP>:5555\n'
    fi
    printf '\nPress Enter to quit...'
    read -r _ || true
    printf '\n'
    exit 1
  fi

  if [ "${#online[@]}" -eq 1 ]; then
    export ADB_SERIAL="${online[0]}"
    printf 'Using ADB device: %s\n' "$ADB_SERIAL"
    return 0
  fi

  printf '\nAvailable ADB devices:\n'
  for i in "${!online[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${online[$i]}"
  done

  while true; do
    printf 'Select device [1-%d] (Enter to quit): ' "${#online[@]}"
    read -r choice || choice=""
    if [ -z "$choice" ]; then
      printf 'No device selected. Quitting.\n'
      exit 1
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#online[@]}" ]; then
      export ADB_SERIAL="${online[$((choice - 1))]}"
      printf 'Using ADB device: %s\n' "$ADB_SERIAL"
      return 0
    fi
    printf 'Invalid selection: %s\n' "$choice"
  done
}
