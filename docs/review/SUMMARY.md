# Review Summary

Synthesis of steps 01–11 at `1c750a8`. IDs: `NN-Px-k` = file `NN`, section `Px`, k-th bullet. `12-*` = new in this step.
P1 check: all 28 P1s re-read against source. 26 hold as written, 1 holds with a corrected scenario (02-P1-3), 1 downgraded (03-P1-5), 0 disputed. 1 new P1 (12-P1-1).

## 1. Totals (after verification)

| Step | P0 | P1 | P2 | P3 |
|---|---|---|---|---|
| 01 Shell, Shared, Models | 0 | 2 | 3 | 8 |
| 02 Backup | 0 | 3 | 6 | 6 |
| 03 Sleep core | 0 | 4 | 10 | 11 |
| 04 Nap, Jet lag | 0 | 1 | 5 | 11 |
| 05 What did, Feeling | 0 | 7 | 16 | 9 |
| 06 World | 0 | 2 | 3 | 9 |
| 07 Countdown, Events, Lunar, OnThisDay | 0 | 2 | 5 | 8 |
| 08 Timers, Tools, More, Settings | 0 | 3 | 6 | 14 |
| 09 Widget, build, release | 0 | 1 | 5 | 8 |
| 10 Tests | 0 | 0 | 8 | 10 |
| 11 Boards (not in 1.0) | 0 | 2 | 8 | 7 |
| 12 Synthesis (new) | 0 | 1 | 1 | 0 |
| **Total** | **0** | **28** | **76** | **101** |

P1s that affect the 1.0 build: 26 (Boards excluded).

New in step 12:
- 12-P1-1 `EveryTime/Backup/FirstRunRestore.swift:14,21` + `ContentView.swift:50-55`: on a fresh install, `pinFeelingOnce` writes `app.tabs` (a non-empty array) on first appear. `hasUserContent` counts any non-empty array, so the re-check after `await CloudDrive.status()` is always false and first-run restore never runs. → judge content by `countedKeys` (user lists) only, not by `app.*`, `world.localIndex` or other settings.
- 12-P2-1 `EveryTime/Features/Sleep/Nap/NapAlarm.swift:376-378`: `UserDefaults.encode` sets `nil` on encode failure, which deletes the key. Same wipe pattern as 01-P1-2, outside `Stored`.

## 2. Cross-cutting themes

**A. Notification budget and scheduling.** Five schedulers (JetLag 40, Events 20, Countdown 10, Lunar 10, ActivityAlarms unbounded) plus the nap chain (9) and WindDown (1) share iOS's 64-pending limit. Each has its own queue and its own read of `pending`. `reschedule`, `isAuthorized` and stale-removal are copied across 4 files. Foreground presentation, permission state and trigger type are decided per feature.
Explains: 04-P2-2, 07-P2-1, 04-P2-3, 04-P2-4, 05-P1-5, 05-P2-12, 05-P1-2 (repeating trigger outlives the pin), 07-P1-1, 04-P3-3, 07-P2-2, 07-P3-2, 07-P3-4, 08-P1-2, 02-P2-1, 02-P2-2, 10-P2-8.
Fix: one `NotificationBudget` (serial, `@MainActor`).
- Each feature supplies `wanted(now:) -> [Request]` with a priority and fire date.
- The budget reserves slots for nap, wind-down and timers, then fills the rest of the 64 by fire date, with a minimum per feature.
- It diffs pending requests by id plus a content hash and replaces any that changed.
- It uses interval triggers for absolute instants.
- It owns the single `willPresent` policy and the permission state.
- One `refresh()` call, from `.active`, restore, demo switch and store changes.

**B. `Stored` decode-failure fallback and missing persistence.** `Stored` and `UserDefaults.decoded/encode` swallow errors. A decode failure returns the default, and the next write overwrites the history. An encode failure leaves an empty or deleted key. Every read decodes again. Live timer state is never saved.
Explains: 01-P1-2, 12-P2-1, 08-P1-1, 01-P2-2, 03-P2-4, 05-P2-11, 06-P2-1, 02-P3-3, 10 coverage gaps (Codable fixtures).
Fix: one `StoreCodec`, used by both `Stored` and the `UserDefaults` helpers.
- On decode failure, move the bytes to `<key>.corrupt` and refuse to overwrite until the user acts.
- On encode failure, leave the data unchanged and log.
- Cache decoded values keyed by `Data` identity.
- `TimerPersistence` sits on top of it.

**C. Store switches leave global state stale (demo, restore).** Static caches and globals (`SleepSuggestion` statics, `Activity.customStyles`, `Feeling.custom`, `TimerStore`) aren't refreshed when the store is swapped, and the two restore paths do different follow-up work.
Explains: 01-P1-1, 02-P2-1, 02-P2-2, 05-P3-9, 08-P2-2, 03-P3-12, 10-P2-3, 10-P2-4.
Fix: one `AppData.didReplaceStore()`, called by `setDemo`, `BackupRestore` and `FirstRunRestore`. It runs `SleepCycle.current.apply()`, reloads the static caches, calls `NotificationBudget.refresh()` (which also covers ActivityAlarms), `NapAlarm.restore()` and `GlancePublisher.publish()`. Longer term, pass `SleepCycle` as a value.

**D. Backup integrity.** The snapshot keeps only `Data` values, but apply removes everything else. Archive names use local time. "Has content" detection is wrong in both directions.
Explains: 02-P1-1, 02-P1-2, 02-P1-3, 12-P1-1, 02-P2-4, 02-P2-5, 02-P2-6, 02-P3-2, 10-P2-1, 10-P2-2, 10-P3-3.
Fix: one `BackupRestore.apply(_:)` entry point (before-copy, apply, `didReplaceStore`). The snapshot carries plain values, with a deny-list for runtime keys. `hasUserContent` comes from `countedKeys`. A UTC `createdAt` decides ordering.

**E. ActivityLog repeat and alarm consistency.** A daily pin is a mark plus copies, matched to its occurrences within 2 min, with a 14-day horizon counted from the original mark. Edits rebuild marks and drop fields. Alarms are only ever added.
Explains: 05-P1-1, 05-P1-2, 05-P1-3, 05-P1-4, 05-P1-5, 05-P2-2, 05-P2-3, 05-P2-8, 05-P2-12.
Fix: store repeats as an `ActivityRule` (time of day, tag, alarm, skipped days) and expand occurrences on read. Move `record`/`setTag` into pure `ActivityLog` functions that change fields in place. Alarms go through the budget (A).

**F. Open-ended spans and day bucketing.** Open spans are capped in one place but not another. Spans are counted on the day they start. `86_400` is used as the length of a day.
Explains: 05-P1-7, 05-P2-1, 05-P2-7, 05-P3-4, 05-P2-6, 08-P1-3, 08-P2-1, 08-P2-3, 03-P1-4.
Fix: one `Span` helper in `Shared/` with `capped(maxOpen:)`, `clipped(to: dayInterval)` and `days(in:calendar:)` that iterate calendar days. WorkLog, ActivityLog, FeelingLog and sleep debt all use it.

**G. DST and half-hour zone handling.** Loops step by the hour, check `component(.hour)`, scan a fixed 24 h window, call `date(bySettingHour:of: .now)`, or use formatters with no time zone.
Explains: 06-P1-2, 06-P3-1, 06-P3-2, 06-P3-3, 06-P3-6, 01-P3-5, 01-P2-1, 03-P2-2, 05-P2-5, 05-P2-6, 04-P2-5, 07-P2-2, 09-P2-3, 09-P3-1, 02-P1-2, 10-P2-6.
Fix: `DayMath` in `Shared/` with:
- `dayInterval(for:)`
- `wallClockFraction(_:)`
- `clockText(minutes:)` from a fixed reference day
- 15-minute stepping for zone overlap

Add one shared `America/New_York` DST fixture in `TestSupport`.

**H. Double-scheduling races in alarms.** The sequence is `cancel()`, then `await schedule`, then save the id, in `Task`s that aren't serialized. Nothing checks the app's state against AlarmKit's.
Explains: 03-P1-5 (now P2), 04-P2-1, 04-P1-1, 05-P2-12, 07-P2-1.
Fix: one `SerialScheduler` (a chained Task plus a generation token; after each await, drop and cancel stale results), used by `NapAlarm` and `NotificationBudget`. On `.active`, compare `ActiveNap` with `AlarmManager.shared.alarms` and finish any stopped alarm at `nap.alarm`.

**I. Sleep math anchored to the wrong origin.** The fall-asleep latency is clamped at 0, the ring's origin is clamped to now, and cycle lengths that are harmonics tie. "Night" is defined three ways: `Nap.nightLength` (1 h 45 m), `PastNight.minLength` (3 h) and the UI text (3 h).
Explains: 03-P1-1, 03-P1-2, 03-P1-3, 03-P1-4, 05-P1-6, 03-P3-1, 03-P3-12.
Fix: one `CycleGrid(start:latency:cycle:)` used by `WakeCheck`, `SleepRing` and `NightScreen.upAt`, and one `Night.minLength` constant used by Sleep, What did and the text.

**J. Release and privacy.** There is no privacy manifest, and the release checks only warn.
Explains: 09-P1-1, 09-P2-4, 09-P2-5, 09-P3-1, 09-P3-2, 09-P3-3, 11-P2-8, 01 Improvements (`UIBackgroundModes: audio`).
Fix: add `PrivacyInfo.xcprivacy` to both bundles, plus a `make preflight` (clean tree, no placeholders, manifest present, tests pass) that `release-ios.sh` runs first.

**K. Smaller shared patterns.**
- Duplicate view ids (06-P1-1, 11-P2-6, 05-P2-2) → ids that encode the occurrence or role.
- One `EKEventStore` per feature (07-P1-2, 07-P2-3, 07-P2-4, 11-P2-8) → a shared `EventStoreProvider`.
- Cursor rings with no VoiceOver control (05-P2-13, 06-P3-9, 03-P3-9) → one `.cursorAdjustable(step:)` modifier.

## 3. Top 20 fixes

| # | Fix | Files | Sev | Effort | Closes |
|---|---|---|---|---|---|
| 1 | Add privacy manifests | `EveryTime/PrivacyInfo.xcprivacy`, `EveryTimeWidget/PrivacyInfo.xcprivacy` | P1 ship blocker | S | 09-P1-1 |
| 2 | Backup carries plain values; apply no longer wipes them | `Backup/BackupSnapshot.swift`, `Backup/README.md`, `BackupTests.swift:87` | P1 data loss | M | 02-P1-1, 02-P2-6, 10-P2-1 |
| 3 | First-run restore detects content by user lists | `Backup/FirstRunRestore.swift`, `BackupSnapshot.swift`, `AutoBackup.swift` | P1 data loss | S | 12-P1-1, 02-P1-3, 02-P2-1 |
| 4 | Safe `StoreCodec` (quarantine on decode failure, no write on encode failure) + Codable fixtures | `Shared/Stored.swift`, `Sleep/Nap/NapAlarm.swift:370-379` | P1 data loss | M | 01-P1-2, 12-P2-1 |
| 5 | Persist live timer state | `Shared/TimerStore.swift`, `Timers/ElapsedClock.swift`, LeetCode/Stopwatch models | P1 data loss | M | 08-P1-1 |
| 6 | Backup names and ordering in UTC | `Backup/BackupArchiveName.swift`, `BackupTests.swift` | P1 | S | 02-P1-2, 10-P2-2, 10-P3-3 |
| 7 | `AppData.didReplaceStore()` hook | `Shared/AppData.swift`, `Backup/BackupRestore.swift`, `FirstRunRestore.swift`, `ActivityLog.swift`, `FeelingLog.swift` | P1 | S | 01-P1-1, 02-P2-2, 05-P3-9 |
| 8 | AlarmKit stop reconcile + serialized nap scheduling | `Sleep/Nap/NapAlarm.swift` | P1 | M | 04-P1-1, 03-P1-5, 04-P2-1 |
| 9 | `CycleGrid` for chips and ring | `Sleep/WakeCheck.swift`, `SleepRing.swift`, `NightScreen.swift` | P1 | M | 03-P1-1, 03-P1-2, 03-P3-1 |
| 10 | Cycle learning: phase error + prior toward 90 | `Sleep/WakeCheck.swift:79-88` | P1 | S | 03-P1-3 |
| 11 | One night definition; debt by wake day over 7 days | `WakeCheck.swift:161-166`, `PastNights.swift`, `ActivityLog.swift:131,231` | P1 | S | 03-P1-4, 05-P1-6 |
| 12 | Pure `record`/`setTag` (keep fields; moments don't reuse span pins) | `WhatDid/WhatDidView.swift:420-445`, `ActivityLog.swift` | P1 | S | 05-P1-3, 05-P1-4 |
| 13 | Daily repeats as `ActivityRule` | `WhatDid/ActivityLog.swift`, `WhatDidView.swift`, `MarkEditor` | P1 | L | 05-P1-1, 05-P1-2, 05-P2-2, 05-P2-8 |
| 14 | `NotificationBudget` (shared 64-slot scheduler, diff by content, one `willPresent`) | 4 `*Notifications.swift`, `ActivityLog.swift:309-340`, `NapAlarm.swift:345-352`, `EveryTimeApp.swift` | P1 | L | 05-P1-5, 07-P1-1, 04-P2-2, 07-P2-1, 05-P2-12, 07-P2-2, 04-P2-4, 04-P3-3, 07-P3-2 |
| 15 | Time's-up notification for Interview/Rehearsal | `Timers/CountdownView.swift:136-157` (via budget reserve) | P1 | S | 08-P1-2 |
| 16 | WorkLog `deleteDay` trims by calendar day | `Timers/WorkLog.swift:46-48` | P1 | S | 08-P1-3 |
| 17 | Feeling: close stale opens at `maxOpen`; a past-cursor start ends at the next mark | `Feeling/FeelingLog.swift:96-106` | P1 | S | 05-P1-7, 05-P2-1 |
| 18 | World: unique local row id + `OverlapFinder` at 15-min steps | `World/WorldView.swift`, new `Models/OverlapFinder.swift` | P1 | M | 06-P1-1, 06-P1-2, 06-P2-3, 06-P3-1 |
| 19 | Calendar import uses series start / contact birthday | `Events/CalendarEventPicker.swift:36-60` | P1 | M | 07-P1-2, 07-P2-4 |
| 20 | Release preflight | `Makefile`, `scripts/release-ios.sh` | P2 | S | 09-P2-4, 09-P2-5, 09-P3-1 |

Not ranked: the Boards P1s (11-P1-1, 11-P1-2) are fixed before Boards is re-enabled, not for 1.0.

## 4. Fix order (one commit each)

| Batch | Fixes | Test from 10-tests.md |
|---|---|---|
| 1 | #1 privacy manifests | `privacyManifestBundled` |
| 2 | #2 plain values in backup | `applyKeepsPlainAppStorage`, flip `BackupTests.swift:87` |
| 3 | #3 first-run content check | `firstRunSkipsSettingsOnlyArchive` (+ fresh-install `app.tabs` case) |
| 4 | #6 UTC archive names | `namesOrderAcrossZones` |
| 5 | #4 `StoreCodec` | `undecodableDataIsNotOverwritten` + Codable fixtures per stored model |
| 6 | #5 timer persistence | `clockStateSurvivesRelaunch` |
| 7 | #7 `didReplaceStore` | `setDemoReappliesCycle`; host-app guard (10-P2-4) and `useDefaultCycle()` inits (10-P2-3) in the same commit |
| 8 | #16 WorkLog trim | `deleteDayTrimsNightShift` + WorkLog midnight/DST suite |
| 9 | #17 Feeling | `staleOpenFeelingClosesAtMaxOpen` |
| 10 | #12 record/setTag | `setTagKeepsRepeatAndAlarm`, `momentDoesNotReuseSpanPin` |
| 11 | #11 nights and debt | `twoHourNapIsNotANight`, `daytimeLongSleepPaysDebt` |
| 12 | #9 `CycleGrid` | `nextCycleEndDuringLatency`, `ringGridAnchorsToBed` |
| 13 | #10 cycle learning | `harmonicsPreferNinety` |
| 14 | #8 NapAlarm serial + reconcile | `staleScheduleIsDropped`, `stoppedSystemAlarmFinishesNap` |
| 15 | #13 `ActivityRule` | `deletedRepeatStaysDeleted`, `dailyPinOlderThan14Days` |
| 16 | #14a `NotificationBudget` core + jet lag/events/countdown/lunar | budget allocation test (80 wanted → 64, per-feature minimum) |
| 17 | #14b ActivityAlarms + `willPresent` via budget | `editedAlarmIsReplaced`, `foregroundShowsCountdownBanner` |
| 18 | #15 timer time's-up | `timesUpNotificationDelay` |
| 19 | #18 World | `localZoneCityHasUniqueRow`, `overlapHalfHourZone` |
| 20 | #19 calendar import | `recurringHitUsesSeriesStart` |
| 21 | #20 release preflight | none (script); run `make preflight` once |

## 5. Disputed or downgraded

| Finding | Verdict | Reason |
|---|---|---|
| 03-P1-5 NapAlarm double schedule | Downgraded to P2, merged with 04-P2-1 | Real, but the window is one `AlarmManager.schedule` await, and it needs two chip taps (or a Cancel) inside it. It's the same finding as 04-P2-1, which already rates it P2. Fixed in #8. |
| 02-P1-3 first-run restores a settings-only archive | Holds, scenario corrected | `world.localIndex` is only written on reorder (`WorldView.swift:327`), not on launch. The proposed fix (`hasUserContent`) fails, because `app.tabs` (a non-empty array written by `pinFeelingOnce`) is in every archive and counts as content. The same cause blocks first-run restore entirely (12-P1-1). |
| 01-P1-2 `Stored` fallback | Holds, latent | No current schema break found; it triggers on a future non-optional field or an encode failure. Kept P1 because a single failure can wipe a whole history list. |
| 07-P1-1 `willPresent` returns `[]` | Partly holds | iOS's default is also no foreground banner, so this is a missed opportunity, not a regression. P1 stands for countdowns, where a banner is the only time's-up signal away from the detail screen. Event and lunar 9:00 reminders are P3 (as 04-P3-3). |
| 09-P1-1 privacy manifest | Holds | A release blocker (ITMS-91053) rather than a wrong result a user sees; ranked first. |
| 11-P1-1, 11-P1-2 Boards | Hold, deferred | Code confirmed (`BoardStore.swift:173-213`, `BoardSettingsSheet.swift:169-176`), but Boards is excluded from the 1.0 target, so no user impact for 1.0. |
