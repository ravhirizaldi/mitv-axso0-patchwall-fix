# Mi TV AXSO0 — PatchWall popup fix, debloat, and RAM guard

> **Disclaimer:** This repository was made by AI — no human hand on the keyboard, just a model with a plan and a terminal — and verified on a real MiTV-AXSO0 running Android 9. Not affiliated with Xiaomi or Google. Use at your own risk and read the scripts before running them.

## What this repo does

A set of ADB scripts for an **unrooted Xiaomi Mi TV**. It:

1. Stops PatchWall's **“Xiaomi TV+ / Instal apl ini?”** popup.
2. Disables PatchWall's background and telemetry components.
3. Stops seven media/store apps from auto-starting after reboot.
4. Makes **Quasar** (`com.quasartv.launcher`, self-made) the default home screen.
5. Re-applies the 14 packages that were already disabled on the tested TV.

It does **not** modify the PatchWall APK, does **not** need root, and does **not** factory-reset the TV.

## Which TV this is for

Use it only on the same model and firmware it was tested on:

| | |
|---|---|
| Model | MiTV-AXSO0 (`dangal`) |
| Android | 9, user build |
| RAM | 1 GB |
| PatchWall | `com.mitv.tvhome.atv` 4.4.23 (system base 3.8.2) |
| Root | No — bootloader locked, no `su` |
| Launcher | Quasar (`com.quasartv.launcher`, self-made); stock Google TV launcher disabled |
| Verified on a real TV | Yes |

Other Mi TV models can use different package and component names. Running the scripts blindly on a different TV can disable the wrong things. Check the package lists below against your own TV first.

## What gets changed

### 1. The TV+ popup

PatchWall checks for `com.mitv.tvhome.mitvplus` before showing the install prompt. This repo installs a tiny **dummy** package with that name (version code `2000000000`), then disables it. PatchWall sees a “new enough” TV+ package and skips the popup; the fake TV+ cannot open, and the failure is caught by PatchWall.

This is **not** the real Xiaomi TV+. If you later want the real TV+, uninstall the dummy first.

### 2. Package-level disables (14)

These are the packages that were disabled on the tested TV. Most were already off; the script re-applies the same state after a factory reset. It does **not** add new packages to this list.

| App | Package |
|---|---|
| Android Print Spooler | `com.android.printspooler` |
| Google TV search (Katniss) | `com.google.android.katniss` |
| Google TV launcher recommendations | `com.google.android.leanbacklauncher.recommendations` |
| Stock Google TV launcher (original default) | `com.google.android.tvlauncher` |
| Google TV recommendations | `com.google.android.tvrecommendations` |
| Google Play Movies & TV | `com.google.android.videos` |
| YouTube Music for TV | `com.google.android.youtube.tvmusic` |
| Xiaomi TV+ dummy (installed by this repo) | `com.mitv.tvhome.mitvplus` |
| Mi TV analytics | `com.miui.tv.analytics` |
| Mi Music | `com.xiaomi.mimusic2` |
| Mi TV handbook | `com.xiaomi.mitv.handbook` |
| Mi TV manager | `com.xiaomi.mitv.tvmanager` |
| Mi TV update service | `com.xiaomi.mitv.updateservice` |
| Xiaomi statistics | `com.xiaomi.statistic` |

Disabling `com.xiaomi.mitv.updateservice` means **no OTA updates**. Re-enable it if you want Xiaomi system updates.

### 3. PatchWall background components (10)

`apply_debloat.sh` disables these inside PatchWall:

- WorkManager background job and alarm services
- Firebase Measurement/Analytics receiver, service, job service, and install-referrer receiver
- Firebase Instance ID receiver
- Firebase data-transport alarm receiver
- Skyeye statistics receiver and log-analysis service

PatchWall still opens and loads content. This only removes background jobs and telemetry.

### 4. Apps stopped from auto-starting (7)

All seven are force-stopped, blocked from background execution, and have their boot / WorkManager reschedule receivers disabled. They stay installed and launch normally when you open them.

| App | Package |
|---|---|
| Apple TV | `com.apple.atve.androidtv.appletv` |
| Google Play Store | `com.android.vending` |
| PatchWall | `com.mitv.tvhome.atv` |
| Hotstar | `in.startv.hotstar.dplus.tv` |
| Max | `com.wbd.stream` |
| Netflix | `com.netflix.ninja` |
| Prime Video | `com.amazon.amazonvideo.livingroom` |

The Play Store will not auto-update apps until you open it. PatchWall cold-starts in about 35–40 seconds after being stopped.

### 5. Quasar as the default home

`ensure_quasar_home.sh` sets `com.quasartv.launcher/.MainActivity` as the default HOME. Quasar is the self-made launcher. The stock Google TV launcher (`com.google.android.tvlauncher`) was already disabled before this repo. `com.tvlauncher` is a third-party launcher installed before Quasar; it remains installed and enabled as a secondary HOME candidate, but it is not the default. No script stops or disables Quasar or `com.tvlauncher`.

## Before you start

- A computer with **ADB** (Android platform-tools).
- ADB debugging enabled on the TV, and the computer authorized.
- The TV and computer on the same network (for `adb connect`) or connected by USB.
- A **bash** shell: Linux, macOS, WSL, or Git Bash. The scripts are not `.bat` files.

## How to use

```bash
git clone https://github.com/ravhirizaldi/mitv-axso0-patchwall-fix.git
cd mitv-axso0-patchwall-fix

adb connect <TV-IP>:5555     # skip if using USB
adb devices                  # must show "device", not "unauthorized"

chmod +x *.sh                # only if the executable bit was lost
./apply_all.sh
```

`apply_all.sh` runs the setup in this order:

1. Select the ADB device.
2. Set Quasar as default HOME.
3. Install and disable the TV+ dummy.
4. Re-disable the 14 packages.
5. Disable the 10 PatchWall components.
6. Force-stop and block the seven media/store apps.

If multiple ADB devices are connected, it shows a numbered menu. If none are found, it prints a warning and waits for **Press Enter to quit...** before exiting.

## Verify

```bash
# Quasar should be the default home
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

# Should list the 14 packages above
adb shell pm list packages -d

# All seven should print "stopped" (empty pidof)
for p in com.apple.atve.androidtv.appletv com.android.vending com.mitv.tvhome.atv \
         in.startv.hotstar.dplus.tv com.wbd.stream com.netflix.ninja \
         com.amazon.amazonvideo.livingroom; do
  printf '%-45s ' "$p"
  adb shell pidof "$p" || echo stopped
done
```

## Test the reboot block

```bash
adb reboot
```

Wait for the TV to boot, then run the `pidof` loop again. All seven should still be stopped. If one comes back, run `./apply_ram_guard.sh` again. If it keeps coming back, the script comments show how to hard-disable that package.

## Revert

```bash
./revert_popup_fix.sh      # remove the TV+ dummy; the popup may return
./revert_debloat.sh        # re-enable the PatchWall components
./revert_ram_guard.sh      # restore boot receivers and background AppOps
```

`revert_ram_guard.sh` restores the boot receivers and background AppOps; the apps stay stopped until you open them.

The other package-level disables are **not** automatically reverted, because some of them were already disabled by Xiaomi. To bring an app back, enable it manually:

```bash
adb shell pm enable <package>
```

System packages may refuse the plain `pm enable`; use the TV settings or the same TvService channel used by `apply_disabled_packages.sh`:

```bash
adb shell "service call TvService 3 s16 'cmd package enable --user 0 <package>'"
```

Re-enabling analytics, statistics, or the update service may bring back telemetry, bloat, or OTA updates.

## Things to know

- **No root and no APK modification.** PatchWall itself is untouched.
- **Promo tiles stay.** The Xiaomi TV+, Prime Video, and other tiles on the PatchWall home screen are CMS content, not ad-SDK banners. These scripts cannot remove them.
- **YouTube ads stay.** This does not patch YouTube or block its ads.
- **The TV+ dummy conflicts with the real Xiaomi TV+.** Uninstall it before installing the real app.
- **ADB is powerful.** Port 5555 can run system-level commands on this TV. Keep ADB off when you are done and do not expose it to untrusted networks.
- **Launcher names are easy to confuse.** `com.quasartv.launcher` is Quasar (self-made, current default). `com.tvlauncher` is an older third-party launcher, not the OEM default. The stock Google TV launcher is `com.google.android.tvlauncher`, and it is disabled.
- **This is model-specific.** Do not run it on another Mi TV without checking the packages and components first.

## Files

| File | Purpose |
|---|---|
| `apply_all.sh` | Run everything in order |
| `adb_select.sh` | Interactive ADB device picker |
| `ensure_quasar_home.sh` | Set Quasar as default HOME |
| `apply_popup_fix.sh` / `revert_popup_fix.sh` | Install/remove the TV+ dummy |
| `apply_debloat.sh` / `revert_debloat.sh` | Disable/restore the 10 PatchWall components |
| `apply_disabled_packages.sh` | Re-disable the 14 packages in `disabled_packages.txt` |
| `disabled_packages.txt` | The package list |
| `apply_ram_guard.sh` / `revert_ram_guard.sh` | Stop/restore the seven media/store apps |
| `stub-tvplus.apk` | The dummy TV+ package |
| `TECHNICAL.md` | APK analysis, evidence, DNS notes, security note, root assessment |

## Technical details

The full deep-dive — APK analysis, evidence commands, DNS ad blocking, the `TvService` security note, and the root assessment — is in [TECHNICAL.md](TECHNICAL.md).
