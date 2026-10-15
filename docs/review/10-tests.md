# 10 Tests

Reviewed at `1c750a8`: all of `EveryTimeTests/` (Board* skipped, step 11), against findings 01–09.
Good: dates are built through `date(...)`/`gregorian()` with a pinned zone, `calendar:` is passed almost everywhere, Cron/NapAdvice/JetLag cover a real DST zone, backups use a throwaway `UserDefaults` suite.

## P0
- none found

## P1
- none in the tests themselves. All 26 P1s from steps 01–09 have no regression test (table below). One test asserts the buggy behavior (see the first P2).

## P2
- `EveryTimeTests/BackupTests.swift:87`: `#expect(defaults.object(forKey: "app.string") == nil)` locks in P1 02 (apply wipes plain `@AppStorage` values). The fix will turn this test red. → flip it to `defaults.string(forKey: "app.string") == "plain"` along with the fix.
- `EveryTimeTests/BackupTests.swift:133`: `BackupArchiveNameTests` builds `when` with `gregorian(.current)`, so it passes in any zone and hides P1 02 (names stamped in the device zone). → pin the zone and add a two-zone ordering test (table).
- `EveryTimeTests/SleepSuggestionTests.swift:5`: the suite has no `init() { useDefaultCycle() }`, yet `bedtimes`, `wakeTimes` and `fit` read the `SleepSuggestion` statics. Run alone on a device with a learned or manual cycle (applied by the host at `EveryTimeApp.swift:13`), it fails. In a full run it passes only because other suites reset the statics first. → add the init. `ActivityLogTests.swift:5` has the same gap (`ActivityLog.minNight` = `Nap.nightLength` reads the statics). It passes today only because its cases are far from the threshold.
- `EveryTimeTests/TestSupport.swift:19-22` with `EveryTime/EveryTimeApp.swift:9-24`: the tests run inside the real app host. The host's `init` applies the device's cycle, `.task` runs `FirstRunRestore.runIfNeeded()` (iCloud → `snapshot.apply()` on the real store), and the Sleep tab's `loadHealth` may set `SleepCycle.current` (`SleepTimeView.swift:415`) while parallel suites run. These are race and flake sources, and a test run can write user data on the physical device. → when `XCTestConfigurationFilePath` is set, skip `FirstRunRestore` and render an empty scene. Longer term, pass the cycle as a value (03 Improvements) and drop `useDefaultCycle()`.
- `EveryTimeTests/SleepNowTests.swift:146`: `fitLine.hasPrefix("7h 15m · 4.7 cycles · ")`, but `fitLine` uses `.formatted(.number…)` (`SleepHero.swift:32`), which is locale-dependent ("4,7" in de/fr). The test fails on a device set to such a locale. → compare against `4.7.formatted(.number.precision(.fractionLength(1)))`, or format with an injected locale.
- `EveryTimeTests/TestSupport.swift:4-5`: every default date is Asia/Shanghai, which has no DST. ActivityLog `today`/`dailyAverages`, PastNights, SleepTrend, Anniversary, BackupRetention and WhatDid repeats are never exercised on a 23 h or 25 h day. → add one `America/New_York` case per day-bucketing function (Mar 8 and Nov 1 2026).
- `EveryTimeTests/WakeCheckTests.swift:10-15`: `firstMinutesDontCount` tests at 23:20 with a 15-min latency, so `elapsed > latency`. It never checks `nextCycleEnd` inside the latency window, which is exactly where P1 03 lives.
- Untestable seams (pure logic that is `private` or reads `.current`): `upcomingRequests`/`nextFire` are private in `CountdownNotifications.swift:44`, `ImportantEventNotifications.swift:45,69`, `LunarNotifications.swift:47` and `JetLagNotifications.swift:42`. `WorkLog.csv(at:)` (`WorkLog.swift:93`) has no calendar or time-zone parameter. The overlap finder (`WorldView.swift:224-237`), the bed/wake resolution (`SleepTimeView.swift:114-137`) and `record`/`setTag` (`WhatDidView.swift:426-445`) sit in views. → make them `internal` with `now:`/`calendar:` parameters, or move them into model types.

## P3
- `EveryTimeTests/DemoSeedTests.swift:57-60`: both asserts are near tautologies (`demoSuite` always ends in `.demo-data`, and `demoDefaults` is `.standard` only if the suite init fails). → assert that `DemoSeed.seed()` leaves a sentinel key in `UserDefaults.standard` untouched.
- `EveryTimeTests/DemoSeedTests.swift:35`: `load(now: .now)` depends on the real clock and `TimeZone.current` (it filters out the local city), so `count >= 5` depends on the device zone. → pass a fixed `now`. Also add the 01 case: the day stamp across UTC midnight.
- `EveryTimeTests/BackupTests.swift:162,179-187`: names come from `auto()` in the device zone but are grouped with a Shanghai calendar. Today this works by round-trip luck. Once names move to UTC (P1 02 fix), pin both explicitly.
- `EveryTimeTests/NapAdviceTests.swift:6`: the global `napAdvice()` helper lives in one test file but is used by `SleepNowTests` and `WakeCheckTests`. → move it to `TestSupport.swift`.
- `EveryTimeTests/NapAdviceTests.swift:110`: a `Nap.minutes` clamp assertion sits inside `activeNapAlarm`. → give it its own test.
- `EveryTimeTests/SleepNowTests.swift:144`: exact `Double` compare `== 4.666666666666667`. → `abs(x - 14.0/3) < 1e-9`.
- `EveryTimeTests/SleepNowTests.swift:98`: `now.tip != nil` is weak. → assert the text or a prefix.
- `EveryTime/Features/Sleep/JetLag/JetLagPlanner.swift:10`: the `now` parameter is unused, so tests can't pin it and don't need to. Remove it, or use it and test it.
- `EveryTime/Features/Tools/CronExpression.swift:300-307`: summaries with month or weekday names use `Calendar.current` symbols and are untested. Results are locale-dependent.
- `EveryTimeTests/LunarTests.swift:62-67` is the only "older JSON decodes" test. Copy the pattern for each stored model (see table).

## Coverage gaps (pure logic, no tests)
- `Shared/Stored.swift`, `UserDefaults.decoded/encode` (`NapAlarm.swift:370-379`): round trip, decode failure, encode failure (NaN).
- Codable back-compat fixtures: `ActivityMark`, `Nap`, `ActiveNap`, `Countdown`, `ImportantEvent`, `WorldCity`, `Trip`, `JetLagProfile`, `SleepCycle`, `WorkSpan`, `FeelingMark`.
- `WhatDid/ActivityLog.swift:144-176` `planned`/`dueRepeats`/`occurrenceID`, plus `meanClock` and `dailyAverages`.
- `Feeling/FeelingLog.swift:81-115` (`spans`, `active`, `starting`, `ending`).
- `Timers/WorkLog.swift` (`days` midnight split, `today`, `deleteDay`, `csv`, `hoursMinutes`, `state`). Also `ElapsedClock`, `StopwatchModel.lap`, `ParsedTimestamp`, `TimeText`.
- `NapSession.canCancel`/`finish` natural flag (`NapAlarm.swift:46,59-73`). The alarm scheduling generation logic needs a seam first.
- World overlap finder and `TimelineGrid` hours (half-hour zones, a wrapping 22–6 range, DST days).
- `Anniversary` around Feb 29 (`elapsed`/`years` on Feb 28 of a common year), `CountdownReadout` boundaries, `CountdownEditor.Preset.date`, `ImportantEventNotifications.nextFire`, `OnThisDay.decodeFeed`.
- `AppTool.pins(from:)`, `SleepRing` geometry, `MorningLog.proposal`, JetLag ±12 h tie, stopover, DST in the pre-adjust window, and the Cron cases `SAT-SUN`, `*/2` DOM and the fall-back hour.

## P1 regression tests (none exist)
| Finding | Test to add | Assertion |
|---|---|---|
| 01 AppData.swift:20 | `setDemoReappliesCycle` | after `setDemo(false)`, `SleepSuggestion.cycleLength == Double(SleepCycle.current.minutes) * 60` |
| 01 Stored.swift:15 | `undecodableDataIsNotOverwritten` | write junk to key, set value via `Stored` → old bytes kept (or copied to `<key>.corrupt`) |
| 02 BackupSnapshot.swift:39-51 | `applyKeepsPlainAppStorage` | after `apply(to:)`, `defaults.string(forKey: "app.tab") == "sleep"` (flip line 87) |
| 02 BackupArchiveName.swift:53 | `namesOrderAcrossZones` | Tokyo 08:00 Oct 16 then SF 18:00 Oct 15 → `newestFirst.first` is the SF file |
| 02 FirstRunRestore.swift:12 | `firstRunSkipsSettingsOnlyArchive` | `acceptable(make(snapshot(["world.localIndex":"0"])))` is false |
| 03 WakeCheck.swift:17-24 | `nextCycleEndDuringLatency` | `WakeCheck(start: 23:00, now: 23:02).nextCycleEnd == 00:45` |
| 03 SleepRing.swift:96-99 | `ringGridAnchorsToBed` | bed 23:00, now 01:00 → cycle ends `[00:45, 02:15, 03:45, 05:15]` |
| 03 WakeCheck.swift:79-88 | `harmonicsPreferNinety` | `learned(from: wakes 445/450/455/448/452 + 15, fallAsleep: 15)?.minutes == 90` |
| 03 WakeCheck.swift:161-166 | `daytimeLongSleepPaysDebt` | `debt([night 6h, sleep 13:00–16:30 same day], need: 8h) == 0`, and nights older than 7 days are ignored |
| 03 NapAlarm.swift:138-146 | `staleScheduleIsDropped` (needs gate seam) | second `begin()` makes the first token `!isCurrent` |
| 04 NapAlarm.swift:218-227 | `stoppedSystemAlarmFinishesNap` (needs seam) | `reconcile(active: nap, systemIDs: [], now: 17:00)` logs `end == nap.alarm` |
| 05 ActivityLog.swift:165 | `deletedRepeatStaysDeleted` | after deleting Sat 09:00 occurrence, `dueRepeats(at: Sat 10:00).isEmpty` |
| 05 ActivityLog.swift:147,168 | `dailyPinOlderThan14Days` | pin 20 days old → `planned(at:)` contains tomorrow 09:00 and `dueRepeats` today's 09:00 |
| 05 WhatDidView.swift:443 | `setTagKeepsRepeatAndAlarm` | retagged mark still `isDaily && alarm == true` |
| 05 WhatDidView.swift:426 | `momentDoesNotReuseSpanPin` | record work 09:00, coffee 09:04 → tags `["work","coffee"]` |
| 05 ActivityLog.swift:322 | `editedAlarmIsReplaced` (needs diff seam) | `ActivityAlarms.diff(pending: 14:00, wanted: 15:30)` → replace |
| 05 ActivityLog.swift:131 | `twoHourNapIsNotANight` | `log([sleep 14:00, nil 16:00]).nights(at: 17:00).isEmpty` |
| 05 FeelingLog.swift:96-104 | `staleOpenFeelingClosesAtMaxOpen` | Happy yesterday 09:00, start Sad today 10:00 → Happy `end == yesterday 21:00` |
| 06 WorldView.swift:24-28 | `localZoneCityHasUniqueRow` | rows for cities `[London]` with local London → unique ids, and `move` keeps London in `cities` |
| 06 WorldView.swift:224-237 | `overlapHalfHourZone` | London + Kolkata 08–18 → `[08:00–13:30 London]` |
| 07 NapAlarm.swift:352 | `foregroundShowsCountdownBanner` | `presentation(for: "countdown.x") == [.banner, .sound, .list]` |
| 07 CalendarEventPicker.swift:41 | `recurringHitUsesSeriesStart` (needs seam) | birthday series from 1980 → hit date year 1980 |
| 08 TimerStore.swift:12 | `clockStateSurvivesRelaunch` | `TimerStore(defaults:)` restored → `leetcode.elapsed(at: now) ≈ saved` and problem text kept |
| 08 CountdownView.swift:136 | `timesUpNotificationDelay` | start 45 min with 10 elapsed → pending request fires in 35 min, removed on pause |
| 08 WorkLog.swift:46 | `deleteDayTrimsNightShift` | Mon 22:00–Tue 06:00, `deleteDay(Tue)` → `days()` is only Mon with 2 h |
| 09 (no PrivacyInfo) | `privacyManifestBundled` | `Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil` |

## Tests to add (ordered by value)
| # | Test | Why |
|---|---|---|
| 1 | `applyKeepsPlainAppStorage` + flip `BackupTests.swift:87` | data loss on every restore. The current test asserts the bug. |
| 2 | Codable fixtures per stored model + `undecodableDataIsNotOverwritten` | silent wipe of all history on a schema change |
| 3 | `namesOrderAcrossZones` + `firstRunSkipsSettingsOnlyArchive` | a stale or empty restore on reinstall |
| 4 | `deleteDayTrimsNightShift` + WorkLog `days`/`csv` DST suite | deletes the wrong hours. Cheap, pure. |
| 5 | `deletedRepeatStaysDeleted`, `dailyPinOlderThan14Days`, `twoHourNapIsNotANight`, `staleOpenFeelingClosesAtMaxOpen` | visible WhatDid/Feeling errors, all pure logic |
| 6 | `nextCycleEndDuringLatency`, `harmonicsPreferNinety`, `daytimeLongSleepPaysDebt` | the core sleep math the alarm chips rely on |
| 7 | `useDefaultCycle()` in SleepSuggestion/ActivityLog suites + host-app test guard | removes order-dependent and device-dependent flakes |
| 8 | `overlapHalfHourZone` (after extracting `OverlapFinder`) | wrong meeting hours for India and Nepal |
| 9 | `privacyManifestBundled` | catches the ITMS-91053 upload failure before release |
| 10 | Locale-safe `fitLine` assert, NY DST variants for day bucketing, Anniversary Feb 28 `years`/`elapsed` | hardening |
