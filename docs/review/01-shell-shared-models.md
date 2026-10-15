# 01 App shell, Shared, Models

Reviewed at `1c750a8`: `EveryTime/*.swift`, `Info.plist`, `Shared/`, `Models/`.

## P0
- none found

## P1
- `EveryTime/Shared/AppData.swift:20`: `setDemo` switches the store but never calls `SleepCycle.current.apply()`, so `SleepSuggestion.cycleLength`/`fallAsleepTime` (global statics, `Models/SleepSuggestion.swift:5`) keep the other store's values. Scenario: user with a manual 100-min cycle turns demo on, and demo shows their personal cycle. In demo, `SleepTimeView.loadHealth` (`Features/Sleep/SleepTimeView.swift:415`) writes and applies the demo store's cycle (default 90). After demo is turned off, the real bedtimes, ring and `PastNights` math use 90 min until the next relaunch, while the info text reads `SleepCycle.current` (100). → call `SleepCycle.current.apply()` at the end of `setDemo` in both directions.
- `EveryTime/Shared/Stored.swift:15-16`: decode failure falls back to the default silently, and the next write replaces the stored blob. Scenario: a future release adds a non-optional field to a stored model (activity log, countdowns, etc.) without a custom `init(from:)`. The list shows empty, the user adds one item, and all history is overwritten with `[item]`. Encode failure (e.g. a NaN `Double`, which `JSONEncoder` rejects) writes `Data()` and wipes the key the same way. → on decode failure, keep the raw data and refuse to overwrite it (or copy it to `<key>.corrupt` first). On encode failure, leave `data` unchanged and log the error. Add a test per stored model that decodes the previous version's JSON.

## P2
- `EveryTime/Shared/AppData.swift:110`: `.iso8601.year().month().day()` formats in UTC (the `ISO8601FormatStyle` default), not local. Scenario (UTC-7): seeded at 18:00 on day D the stamp is D+1. At 07:00 on D+1 the stamp still matches, so there's no reseed and "last night" in demo/screenshots is two nights old until 17:00. → `date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())`.
- `EveryTime/Shared/Stored.swift:15`: every `wrappedValue` read runs a full `JSONDecoder` decode, and `projectedValue` binding reads it again. Large lists (`timers.activityLog`, `timers.workLog`) are decoded many times per `body`, e.g. `ContentView.pins` decodes `app.tabs` up to 4 times in `onAppear`. → cache the decoded value keyed by the `Data` (a small `@State` box compared by data identity), or move big lists into `@Observable` stores.
- `EveryTime/Backup/AutoBackup.swift:38-43` (called from `EveryTimeApp.swift:38`): `beginBackgroundTask()` has no expiration handler. If iCloud upload outlasts the background time, the task is never ended before expiry and iOS kills the app (0x8badf00d-style report). → `beginBackgroundTask(withName:expirationHandler:)`, which cancels the Task and ends the background task. Also guard `task != .invalid`.

## P3
- `EveryTime/ContentView.swift:24-28,35`: the jump to the Sleep tab when a nap/night is active only runs in `onAppear` (cold launch). Returning from background mid-night stays on the last tab. → also apply `sleepTab` on `scenePhase == .active`.
- `EveryTime/Shared/AppTool.swift:9` + `ContentView.swift:50`: on a fresh install, `pinFeelingOnce` swaps `.lunar` out of the defaults, so `defaultPins` never takes effect as written. → set `defaultPins = [.world, .sleep, .whatDid, .feeling]` so the code says what users get.
- `EveryTime/Models/TimeZoneQuery.swift:73-75`: any id without "/" (`EST5EDT`, `CST6CDT` when present in the known list) is named by its current offset, e.g. "UTC−4". The zone follows DST, so the saved name is wrong half the year, and `isFixed` returns false for it. → use the offset name only when `zone.nextDaylightSavingTimeTransition == nil`, else keep the raw id.
- `EveryTime/Models/WorldCity.swift:34-38` + `WorldCityData.swift`: capitals with diacritics duplicate zone cities whose names lack them ("Bogotá"/"Bogota", "Asunción"/"Asuncion", "Chișinău"/"Chisinau", "Lomé"/"Lome"). The picker shows two rows for one zone. Search is accent-sensitive: "brasilia" and "male" find nothing. → fold diacritics when building `names` and when filtering (`range(of:options:[.caseInsensitive,.diacriticInsensitive])`).
- `EveryTime/Shared/UnfoldingRow.swift:41,52`: `date(bySettingHour:...of: .now)` on a spring-forward day maps 2:30 to 3:30. Values ≥1440 return nil and fall back to `.now`. → build from a fixed reference day (e.g. 2001-01-01 in `.current`), and clamp to `0..<1440`.
- `EveryTime/Models/WorldCity.swift:8`: an unknown stored id silently falls back to `.current`, so the row shows local time under another city's name. → filter invalid cities on load, or show "unknown zone".
- `EveryTime/Shared/GlancePublisher.swift:3`: the doc says "whenever they change", but it only publishes on scene phase changes, demo off and restore. → fix the comment (behavior is fine since the widget isn't visible while the app is foreground).
- `EveryTime/Shared/FlowLayout.swift:18-19,35`: children are measured and placed with `.unspecified`, so a chip wider than the row overflows instead of wrapping, and each child is measured twice per pass. → propose `ProposedViewSize(width: min(size.width, bounds.width), height: nil)` and cache sizes.

## Improvements
- Replace the `nonisolated(unsafe)` statics in `SleepSuggestion` with an explicit `SleepCycle` parameter (default `.current`). That removes the stale-global class of bugs (P1 above) and the cross-actor race risk.
- `project.yml`: add `INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES` (`UIApplicationSupportsMultipleScenes = false`) explicitly. The SwiftUI `App` is already scene-based, but the key documents it for the iOS 27 scene-lifecycle check.
- `Info.plist` `UIBackgroundModes: audio`: App Review (2.5.4) rejects keep-alive audio. Make sure the nap path plays audible content only, and prefer AlarmKit on iOS 26+ (cross-check in step 04).
- `NSHealthUpdateUsageDescription` is only needed if write access is requested. Drop it if `requestAuthorization(toShare:)` is empty.
- Tests already cover `TimeZoneQuery`, `DemoSeed`, `SleepSuggestion`. Add: `AppTool.pins(from:)` (dupes, unknown, >4), `DemoSeed` day stamp across UTC midnight, `Stored` round-trip with an old schema.
