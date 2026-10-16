# Code Review Plan

Started 2026-10-15 at `1c750a8`. One findings file per step: `docs/review/NN-<area>.md`.
Runs 2 reviewers at a time because the Mac is busy (load ~16 on 10 cores). Progress is checked hourly.

## Per-step checklist (apply to every area)

1. **Correctness**: date/time math (DST, time zones, midnight rollover, leap years, `Calendar` vs fixed 86400s), off-by-one, optionals, force unwraps, edge inputs.
2. **State and persistence**: `@AppStorage`/`Stored` keys, Codable migration, demo store isolation, backup coverage of every key.
3. **Concurrency**: `@MainActor`, Tasks not cancelled, timers leaking, races on shared stores.
4. **Notifications and alarms**: scheduling and cancelling, 64-pending limit, permission denied, identifiers colliding.
5. **SwiftUI**: view identity, heavy work in `body`, `onAppear` refiring, state that should be derived, large views that need splitting.
6. **Privacy and security**: HealthKit/Calendar/Reminders access, entitlements, hardcoded IDs, network calls.
7. **UX and accessibility**: VoiceOver labels, Dynamic Type, dark mode, empty, error and loading states.
8. **Code quality**: duplication across features, dead code, naming, file size, missing tests for pure logic.

Severity levels: **P0** = crash or data loss · **P1** = wrong result a user would see · **P2** = quality or maintainability · **P3** = nit or idea.

## Steps

| # | Area | Files (lines) | Focus | Status |
|---|------|---------------|-------|--------|
| 01 | App shell, Shared, Models | `EveryTime/*.swift`, `Shared/`, `Models/` (~1.3k) | App lifecycle (UIScene), `Stored`, `AppData`, TimerStore, TimeZoneQuery parsing, GlancePublisher | [x] |
| 02 | Backup | `Backup/` (~730) | zip correctness, restore atomicity, retention, iCloud availability, keys missing from snapshot | [x] |
| 03 | Sleep core | `Features/Sleep/*.swift` (~2.35k) | cycle math, SleepRing geometry, WakeCheck, HealthKit, alarm and backup alarm, `SleepTimeView` size | [x] |
| 04 | Nap and Jet lag | `Sleep/Nap/`, `Sleep/JetLag/` (~2.7k) | NapAlarm audio/session, JetLagPlanner shift math across zones, notification volume | [x] |
| 05 | What did and Feeling | `WhatDid/`, `Feeling/` (~1.9k) | ActivityLog ranges and overlaps, drag timeline, 882-line `WhatDidView` split | [x] |
| 06 | World | `World/`, `CityPickerView` (~0.8k) | TimelineGrid scroll perf, DST hours, half-hour zones, overlap finder | [x] |
| 07 | Countdown, Events, Lunar, OnThisDay | 4 folders (~2.5k) | notification scheduling and cleanup, anniversary Feb 29, lunar leap months, Wikipedia fetch errors and caching | [x] |
| 08 | Timers, Tools, More, Settings | 4 folders (~2.35k) | background and lock behavior of timers, WorkLog CSV escaping, cron parser edge cases, demo mode switch | [x] |
| 09 | Widget, Glance, build and release | `EveryTimeWidget/`, `Glance/`, `project.yml`, `Makefile`, `scripts/`, plists, entitlements | App Group snapshot, timeline refresh, signing and secrets, release script safety | [x] |
| 10 | Tests | `EveryTimeTests/` (~1.6k) | gaps compared with steps 01–09, flaky date dependence, time zone pinning | [x] |
| 11 | Boards (excluded from 1.0) | `Boards/` (~2.3k) | light pass only: EventKit misuse, whether to keep it | [x] |
| 12 | Cross-cutting synthesis | all findings | duplicated patterns (notification helpers, stores), architecture, ranked top-20 fix list → `SUMMARY.md` | [x] |

## Findings file format

```
# NN Area
## P0
- `path:line`: problem → suggested fix
## P1 / P2 / P3 …
## Improvements
```

## Progress log

- 2026-10-15: plan written.
- 2026-10-15 08:38: 02 done (P0 0 · P1 3). 03 started.
- 2026-10-15 08:39: 01 done (P0 0 · P1 2). 04 started. Total so far P0 0 · P1 5.
- 2026-10-15 08:43: 04 done (P0 0 · P1 1). 05 started. Total so far P0 0 · P1 6.
- 2026-10-15 08:44: 03 done (P0 0 · P1 5). 06 started. Total so far P0 0 · P1 11.
- 2026-10-15 08:47: 06 done (P0 0 · P1 2). 07 started. Total so far P0 0 · P1 13.
- 2026-10-15 08:48: 05 done (P0 0 · P1 7). 08 started. Total so far P0 0 · P1 20.
- 2026-10-15 08:51: 07 done (P0 0 · P1 2). 09 started. Total so far P0 0 · P1 22.
- 2026-10-15 08:52: 08 done (P0 0 · P1 3). 11 started (10 waits for 09). Total so far P0 0 · P1 25.
- 2026-10-15 08:54: 09 done (P0 0 · P1 1). 10 started. Total so far P0 0 · P1 26.
- 2026-10-15 08:55: 11 done (P0 0 · P1 2; keep excluded and fix before shipping). Waiting on 10. Total so far P0 0 · P1 28.
- 2026-10-15 09:22: 10 done (P2 8; no P1 has a regression test). 12 started.
- 2026-10-15 09:27: hourly check — 01–11 done (P0 0 · P1 28), 12 running.
- 2026-10-15 09:27: 12 synthesis done: 28 P1 verified (1 new, 1 downgraded, 0 disputed); SUMMARY.md saved. Hourly check stopped.

## Fix progress

Branch `review-fixes`. One commit per batch, following SUMMARY.md section 4. Tests run on the physical device (no simulator), then `make device`.

| Group | Batches | Status |
|---|---|---|
| A | 1–4 privacy manifest, backup plain values, first-run check, UTC names | [x] |
| B | 5–7 StoreCodec, timer persistence, didReplaceStore | [x] |
| C | 8–11 WorkLog, Feeling, record/setTag, nights and debt | [x] |
| D | 12–14 CycleGrid, cycle learning, NapAlarm | [x] |
| E | 15 ActivityRule | [x] |
| F | 16–18 NotificationBudget, time's-up | [x] |
| G | 19–21 World, calendar import, preflight | [x] |
- 2026-10-15 13:20: group A done (4 commits, 151 device tests pass). B started.
- 2026-10-15 13:33: group B done (3 commits, 171 device tests pass). C started.
- 2026-10-15 13:39: hourly check: 8 commits, group C running.
- 2026-10-15 14:24: group C done (11 commits total, 189 device tests pass). D started.
- 2026-10-15 14:29: group D done (14 commits total, 195 device tests pass). E started.
- 2026-10-15 14:42: hourly check: 14 commits, group E running.
- 2026-10-15 14:51: group E done (15 commits total, 202 device tests pass). F started.
- 2026-10-15 15:03: group F done (18 commits total, 208 device tests pass). G started.
- 2026-10-15 15:35: group G done. All 21 batches committed (21 commits, 214 device tests pass, make preflight passes). Hourly check stopped.
- 2026-10-15 22:57: batch 13 (#10 cycle learning) reverted at user request (f9096ff); 03-P1-3 reopened.
