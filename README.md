# PatchWall on Mi TV AXSO0 — popup fix, debloat notes, APK-mod verdict

> **Disclaimer:** This repository is AI-generated (LTX-quasar) and has been verified on a real TV — a MiTV-AXSO0 (`dangal`) running Android 9. Every procedure documented here was executed against the live device, and the results (popup gone, debloat applied, RAM guard active, Quasar as default HOME) were observed on-device. It is not affiliated with Xiaomi, Google, or any app vendor. Use at your own risk and read the scripts before running them.

Repository: <https://github.com/ravhirizaldi/mitv-axso0-patchwall-fix>

Date: 2026-10-21  
Device: MiTV-AXSO0 (`dangal`), Android 9, user build  
PatchWall: `com.mitv.tvhome.atv` 4.4.23 (updated 2026-09-27), system base 3.8.2  
State: unrooted — `adb root` denied, no `su`, bootloader locked, verified boot green.

## TL;DR

1. **The APK can be modified, but it cannot be installed over the current PatchWall.** Xiaomi's signature check rejects it (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Without root there is no path to replace a system/priv-app. Evidence below.
2. **The “Xiaomi TV+ / Instal apl ini?” popup is fixed without root**: a dummy `com.mitv.tvhome.mitvplus` package (versionCode 2000000000) is installed and disabled. PatchWall skips the install check; the autoplay's `mitvplus://` launch fails inside a caught exception. No dialog, no crash. Verified.
3. **Background/telemetry debloat applied**: 10 PatchWall components disabled (WorkManager jobs, Firebase Measurement/FID, data transport, Skyeye). PatchWall still boots and loads content. Reversible.
4. **The visible promo tiles** (Xiaomi TV+, Prime Video, etc.) are CMS content, not ad-SDK banners. Component toggles and DNS cannot remove them; that needs a code mod or a different launcher.
5. Backups of both PatchWall APKs plus SHA-256 are in `backup/`.

---

## 1. Why the APK cannot be installed

- The installed 4.4.23 update is signed by Xiaomi (`CN=PatchWall, OU=MiTV, O=Mi`), matching the system base.
- Test: pulled APK, deleted `assets/fonts/MILanTing.ttf`, re-signed with a local test key, then:

```
adb install -r modtest-signed.apk
Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: Package com.mitv.tvhome.atv signatures
do not match previously installed version; ignoring!]
```

- `adb root` → `adbd cannot run as root in production builds`; no `su`; `/system` is read-only; bootloader locked.
- A renamed clone loses `CHANGE_COMPONENT_ENABLED_STATE`, `WRITE_SECURE_SETTINGS`, and Xiaomi signature permissions. It is not viable as a PatchWall replacement.
- Real debloat paths require root:
  - **LSPosed hook** (recommended): keeps the original APK/signature/privileged permissions, hooks the popup, TV+ autoplay, ad presenters, telemetry init.
  - **Magisk/system replacement with a re-signed APK**: loses signature permissions and likely breaks Xiaomi service integration.

---

## 2. Popup fix (applied)

Activity: `com.mitv.tvhome.atv/com.mitv.tvhome.DownloadTipsActivity`  
Action: `com.mitv.tvhome.intent.action.DOWNLOAD_TIPS`

Trigger chain:

```
hero banner autoplay countdown
  -> BlockBannerPlayPresenter.onRedirectToTarget
  -> d0.e.a(...) TV+ branch
  -> Tools.isInstalled("com.mitv.tvhome.mitvplus") == false
  -> update.b update check
  -> DownloadTipsActivity ("Xiaomi TV+ / Instal apl ini?")
```

First attempt: disable `DownloadTipsActivity` via the vendor service. The popup stopped, but PatchWall crashed because `update.b` calls `startActivity` without catching `ActivityNotFoundException`:

```
FATAL EXCEPTION: main
Process: com.mitv.tvhome.atv
android.content.ActivityNotFoundException: No Activity found to handle Intent
{ act=com.mitv.tvhome.intent.action.DOWNLOAD_TIPS ... }
    at com.mitv.tvhome.update.b.a(...)
```

The component was re-enabled. Final fix: a dummy TV+ package.

- `stub-tvplus.apk`: package `com.mitv.tvhome.mitvplus`, versionCode `2000000000`, `hasCode=false`, no activities/services/permissions, signed with a local test key.
- Installed, then `pm disable-user --user 0 com.mitv.tvhome.mitvplus`.
- `Tools.isInstalled` uses `getPackageInfo`, which still returns a disabled package; `getPackageVersion` returns 2000000000 >= the banner's target version, so the update dialog is skipped.
- `TvPlusRedirectHelper.isTvPlusAvailable` also checks `ApplicationInfo.enabled`; the stub is disabled, so it returns false. The server-driven `pw_redirect_tv_plus_switch` therefore will not disable PatchWall's launcher components or enable the TV+ trampoline.
- The autoplay then tries `mitvplus://...`; there is no enabled handler, so `startActivity` throws — caught by `d0.e` (`e6.printStackTrace()`). No crash.

Verification, 40 s after a cold start:

```
mResumedActivity: com.mitv.tvhome.atv/.app.PatchWallActivity
dumpsys activity activities | grep -c DownloadTips  -> 0
logcat:
  START u0 {act=android.intent.action.VIEW
    dat=mitvplus://info/showEpg/0/info/patchwall/channelId/66248 ...}
  W System.err: android.content.ActivityNotFoundException: No Activity found ...
  (no FATAL EXCEPTION)
```

Screenshot: `pw_stub_test.png`.

Caveats:

- If the real Xiaomi TV+ is installed later, uninstall the stub first — the signatures conflict.
- If PatchWall adds an integrity/signature check for TV+, the stub trick can stop working.
- The stub persists across reboots (package state is persistent). It does not need to be re-applied after a normal reboot.

Apply: `./apply_popup_fix.sh`  
Revert: `./revert_popup_fix.sh`

---

## 3. Debloat applied (reversible)

Disabled via the vendor `TvService` command channel (`runSystemCommand`, uid 1000), because ordinary `adb shell pm disable` is refused for a system app's components:

- WorkManager: `SystemJobService`, `SystemAlarmService`
- Firebase Measurement: `AppMeasurementReceiver`, `AppMeasurementService`, `AppMeasurementJobService`, `AppMeasurementInstallReferrerReceiver`
- Firebase messaging: `FirebaseInstanceIdReceiver`
- Firebase data transport: `AlarmManagerSchedulerBroadcastReceiver`
- Skyeye: `SkyeyeStatReceiver`, `LogAnalyzeService`

After a cold start + 35–40 s: PatchWall resumed, no FATAL, no DownloadTips, home content loaded. Native heap dropped from roughly 37.5 MB to 32 MB; Dalvik heap from roughly 9.5 MB to 8.3 MB. Total PSS stays in the ~70–80 MB range depending on content/ads — the big cost is code/SDKs, not these components.

Not touched: `DownloadTipsActivity` (back to default/enabled), `VideoAdPlayActivity`, `UpdateDialogActivity`, launcher aliases, ad presenters.

Apply: `./apply_debloat.sh`  
Revert: `./revert_debloat.sh` (uses `cmd package default-state`)

---

## 4. What makes PatchWall heavy

APK: 22.4 MB total.

| Part | Size |
|---|---:|
| `classes.dex` + `classes2.dex` | 8.2 MB + 6.9 MB = 15.1 MB |
| `lib/` (5 ABIs) | 6.9 MB |
| `assets/` | 8.7 MB |
| `assets/fonts/MILanTing.ttf` | 8.38 MB |
| `res/` | 5.2 MB |
| `resources.arsc` | 1.7 MB |

Device ABI is `armeabi-v7a` only (`ro.product.cpu.abilist=armeabi-v7a,armeabi`). The arm64, x86, x86_64 and armeabi native libraries are dead weight on this TV.

Runtime: ~70–80 MB PSS observed (native heap ~32 MB, Dalvik ~8 MB, plus `.apk`/`.dex`/`.oat` mappings).

Components: 54 activities, 19 services, 21 receivers, 8 providers.

SDKs/libraries seen in the APK: Firebase (521 string refs), OneTrack (301), Google Mobile Ads/GAM + DoubleClick + PubMatic + IMA, Crashlytics, Skyeye, and the native `xcrash` / `koom` / `plog` / `tailor` stack.

Ads:

- Inline GAM/video ads can be reduced at the network level by blocking ad domains (e.g. `googleads.g.doubleclick.net`, `pagead2.googlesyndication.com`, `pubads.g.doubleclick.net`, `imasdk.googleapis.com`, `ow.pubmatic.com`, `update.crashlytics.com`, `reports.crashlytics.com`).
- The promo tiles (Xiaomi TV+, Prime Video, YouTube, etc.) come from the CMS/home API. They are not ad-SDK requests; DNS blocking would break content rather than remove just the promos. Only a code/CMS change or a different launcher removes them.

---

## 5. If you want the real APK debloat (root)

Best path: LSPosed module (root), keeping the original APK and Xiaomi signature.

Hook targets worth starting with:

- `com.mitv.tvhome.DownloadTipsActivity.onCreate` → `finish()` (instead of disabling the component; avoids the uncaught exception path).
- `BlockBannerPlayPresenter.sendMsgToTvPlus` / `onRedirectToTarget` → no-op for the TV+ branch.
- `d0.e` TV+ branch → skip the `update.b`/`mitvplus://` flow.
- `com.mitv.tvhome.ad.*` / `mGamAdManager` → skip ad loading.
- OneTrack / Firebase / Skyeye initialization → skip telemetry.

A re-signed, debloated system APK is possible on a rooted device but loses signature permissions (`CHANGE_COMPONENT_ENABLED_STATE`, `WRITE_SECURE_SETTINGS`, Xiaomi service permissions); expect broken integration.

Without root, the available levers are package/component state (used here), appops/background restrictions, and network filtering.

---

## 6. Re-apply after factory reset

```bash
./apply_all.sh
```

`apply_all.sh` asks for the ADB device when needed, installs the TV+ stub, re-disables the package inventory, reapplies the PatchWall component debloat, and runs the RAM guard. The popup fix does not need a reboot; package and component state persist.

Manual fallback:

```bash
adb install stub-tvplus.apk
adb shell pm disable-user --user 0 com.mitv.tvhome.mitvplus
./apply_debloat.sh          # optional
adb shell am force-stop com.mitv.tvhome.atv
```

---

## 7. Files

- `stub-tvplus.apk` — 8.5 KB dummy TV+ package; no code, no permissions, no components.
- `adb_select.sh` — shared interactive ADB device selector.
- `apply_all.sh` — full reapply: Quasar HOME, TV+ stub, disabled packages, PatchWall debloat, RAM guard.
- `apply_popup_fix.sh`, `revert_popup_fix.sh`
- `apply_debloat.sh`, `revert_debloat.sh`
- `ensure_quasar_home.sh`
- `apply_disabled_packages.sh`, `disabled_packages.txt`
- `apply_ram_guard.sh`, `revert_ram_guard.sh`
- `backup/PatchWall-4.4.23-original.apk` — SHA-256 `de3fc8925f731e592308df17972c6dbf180065c86e51affabd370570dfd3dfdd` (local only, not committed — proprietary Xiaomi binary)
- `backup/PatchWall-3.8.2-system.apk` — SHA-256 `2b95b8ddeac5c10902e1e5d275d5a78f3e63ba20ef2daad4c4d7084953b0dcec` (local only, not committed — proprietary Xiaomi binary)
- `backup/SHA256SUMS.txt` — hash record for the local APK backups
- `pw_stub_test.png`, `pw_debloat_test.png`

---

## 8. Security note

The vendor `TvService` (`mitv.internal.ITvService`, transaction 3 = `runSystemCommand`) executes an arbitrary command string as uid 1000 without a caller permission check when invoked from `adb shell`. That is a local privilege-escalation surface: anyone with ADB access to this TV can run system-level `cmd`/`am` operations. Keep ADB disabled when not in use and do not expose port 5555 to untrusted networks.

The channel was used here only for component toggles. It does not bypass APK signature verification and does not grant root.

---

## 9. DNS ad blocking (applied)

Private DNS (DNS-over-TLS) is set system-wide to AdGuard DNS:

```bash
adb shell settings put global private_dns_mode hostname
adb shell settings put global private_dns_specifier dns.adguard-dns.com
```

Verified on-device: `doubleclick.net`, `pagead2.googlesyndication.com`, `pubmatic.com`, and `securepubads.g.doubleclick.net` resolve to `127.0.0.1`; `google.com`, `youtube.com`, `redirector.googlevideo.com`, and PatchWall's Xiaomi endpoints (`*.tv.global.mi.com`, `api.account.xiaomi.com`, `c.id.mi.com`) resolve normally.

Manual values if Private DNS is unavailable:

- IPv4: `94.140.14.14` / `94.140.15.15`
- IPv6: `2a10:50c0::ad1:ff` / `2a10:50c0::ad2:ff`
- DoT hostname: `dns.adguard-dns.com`

Revert:

```bash
adb shell settings delete global private_dns_mode
adb shell settings delete global private_dns_specifier
```

Limits: DNS blocking does not remove PatchWall's CMS promo tiles (served from the same endpoints as content), does not block YouTube ads (served from the same domains as video), and the public AdGuard list does not cover Xiaomi's own ad endpoint `global.e.mi.com`. For per-domain control — block Xiaomi ad/telemetry hosts while keeping content — run AdGuard Home on the LAN and point the TV at it.

---

## 10. RAM guard for media/store apps (applied)

Seven packages were force-stopped, background-restricted, and had their boot receivers disabled:

| Package | PSS before | Role |
|---|---|---|
| `com.apple.atve.androidtv.appletv` | 70.4 MiB | Apple TV |
| `com.android.vending` (+ `:background`) | 65.4 MiB | Play Store |
| `com.mitv.tvhome.atv` | 60.3 MiB | PatchWall |
| `in.startv.hotstar.dplus.tv` | 32.3 MiB | Hotstar |
| `com.wbd.stream` | 23.4 MiB | Max |
| `com.netflix.ninja` | 13.0 MiB | Netflix |
| `com.amazon.amazonvideo.livingroom` | 9.9 MiB | Prime Video |

Three persistence layers:

1. `am force-stop` sets `stopped=true`. Android stores this and does not deliver manifest broadcasts — including `BOOT_COMPLETED` — to a stopped package until it is launched.
2. `RUN_IN_BACKGROUND` and `RUN_ANY_IN_BACKGROUND` set to `ignore` (AppOps, persisted in `appops.xml`) block background execution after a manual launch.
3. Each app's `BOOT_COMPLETED` receiver and `androidx.work...RescheduleReceiver` are disabled (persisted in package settings). Apps stay installed and launchable; only the boot path is closed.

Evidence after applying:

- All seven: `pidof` empty, `stopped=true`.
- `MemFree` 49.4 → 203.6 MiB; `MemAvailable` 219.0 → 400.1 MiB.
- Swap in use 169.8 → 114.9 MiB; ZRAM physical 56.6 → 39.6 MiB.
- Top process is now GMS at 72.6 MiB; none of the seven appear in the process list.

Tradeoffs:

- PatchWall cold-starts on next open (35–40 s measured earlier).
- Play Store does not auto-update until opened.
- The apps still launch normally; only preload/background sync is gone.
- If the launcher or an OEM service explicitly launches one, it can clear `stopped`; AppOps still blocks background. For a hard lock, disable the package (`pm disable-user --user 0 <pkg>`). Apple TV, Hotstar, and Max are `/data/app` packages and can be disabled from shell; Netflix, Prime, Play Store, and PatchWall need the `TvService` uid 1000 channel.

Scripts: `apply_ram_guard.sh`, `revert_ram_guard.sh`.

---

## 11. Full reapply, interactive device selection, disabled package inventory, Quasar HOME

Every script sources `adb_select.sh` and calls `adb_select_device` before touching the TV. Device resolution is:

1. `ADB_SERIAL` is used when it points at an online device.
2. Exactly one online device is auto-selected.
3. Several online devices produce a numbered menu.
4. No online device prints a warning (including any `unauthorized`/`offline` entries), waits for **Press Enter to quit...**, then exits non-zero.

No device IP is hardcoded. To pin a specific target without a prompt:

```bash
ADB_SERIAL=192.0.2.10:5555 ./apply_all.sh   # replace with your device serial
```

`apply_all.sh` runs the whole setup in order:

1. `ensure_quasar_home.sh` — sets `com.quasartv.launcher/.MainActivity` as the default HOME and fails if the resolver does not return Quasar.
2. `apply_popup_fix.sh` — installs and disables the TV+ stub.
3. `apply_disabled_packages.sh` — disables every package in `disabled_packages.txt` through the TvService uid 1000 channel.
4. `apply_debloat.sh` — the PatchWall background/telemetry component set.
5. `apply_ram_guard.sh` — force-stop, AppOps, and boot-receiver block for the seven media/store apps. It calls the Quasar guard first and never touches either launcher.

Disabled packages on the device (`pm list packages -d`, all `enabled=3`):

```
com.android.printspooler
com.google.android.katniss
com.google.android.leanbacklauncher.recommendations
com.google.android.tvlauncher
com.google.android.tvrecommendations
com.google.android.videos
com.google.android.youtube.tvmusic
com.mitv.tvhome.mitvplus
com.miui.tv.analytics
com.xiaomi.mimusic2
com.xiaomi.mitv.handbook
com.xiaomi.mitv.tvmanager
com.xiaomi.mitv.updateservice
com.xiaomi.statistic
```

`com.tvlauncher` remains enabled as a secondary HOME candidate, but `cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME` returns `com.quasartv.launcher/.MainActivity`. The Quasar guard re-asserts that on every `apply_all.sh` / `apply_ram_guard.sh` run.
