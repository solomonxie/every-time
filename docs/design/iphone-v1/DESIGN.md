# Every Time — iPhone v1 design

UI: [UIUX_DESIGN.md](UIUX_DESIGN.md) · Build: [IMPLEMENT_PLAN.md](IMPLEMENT_PLAN.md)

## Problem

Time utilities are scattered across many apps: world clock, meeting planner,
practice timers, sleep calculator, dev timestamp tools. Each is small, ad-laden
or paid. One free app should cover them all.

## Goals

- Every tab does real work offline — no placeholder screens in v1.
- User data (cities, timer history, anniversaries) persists on device.
- Zero accounts; network only for On this day (first network feature, cached for offline).

## Non-goals (v1)

- Wait times — removed for 1.0; no free, reliable public wait-time API found yet.
- iCloud sync, iPad layout, landscape.

## Features

| Tab | v1 scope |
|---|---|
| Timers (More) | Stopwatch (laps), Interview countdown, Rehearsal (count down a talk slot, then count up overtime), LeetCode timer + persisted history |
| Countdown (More) | countdowns to a date/time: focus unit biggest (days → hours → minutes → seconds), sideways full screen, fireworks/confetti + sound + vibration at zero, optional notification |
| World (tab 1) | World Time Buddy–style (merged world clock + meeting planner): pinned cities, shared horizontal hour scroll across a week, center cursor, now marker, tappable overlap |
| Sleep | one-tap "Sleep now" / "Nap now" with the alarm on a cycle end — `docs/design/sleep/` |
| Jet lag planner | own tool (was a Sleep segment): per-trip light/sleep/caffeine/melatonin plan — `docs/design/jet-lag/` |
| On this day (More) | Wikipedia feed per date: selected, events, births, deaths, holidays; tap → article; last copy per MM/DD cached offline |
| Boards (on hold, not in the 1.0 build) | ZenHub-style boards over Reminders lists + Calendar milestones — `docs/design/boards/` |
| Lunar (tab) + Important events (More) | important events (manual or picked from iPhone Calendar, typed: birthday, anniversary, memorial…) with time since, next anniversary and a yearly 9:00 reminder; lunar date converter + lunar anniversaries' next Gregorian date |
| Dev tools (More) | live Unix timestamp, timestamp ⇄ date converter, cron expression parser (next runs) |

## Options considered

- Persistence: SwiftData vs Codable JSON in UserDefaults → **JSON/UserDefaults**. Data is tiny (dozens of rows), no queries; avoids schema migrations and keeps the widget/watch able to read it later via an App Group.
- Widget/watch data: share every store vs a small snapshot → **snapshot** (`Glance`: cities + countdowns) in the App Group for the widget, and as WatchConnectivity application context for the watch (App Groups don't cross devices). Published on scene-phase changes.
- Lunar math: own tables vs `Calendar(identifier: .chinese)` → **Foundation**. Built-in, correct, no data files.
- On this day source: `api.wikimedia.org/feed/v1` vs `en.wikipedia.org/api/rest_v1/feed` → **en.wikipedia.org**. Same JSON, no key, long-lived host; cache per MM/DD in Caches, not backups.
- Cron: library vs own parser → **own parser**. Standard 5-field syntax is ~150 lines; no SPM dependency.
- Separate Clocks list + Meetings planner vs one screen → **merged into World**. The planner's cursor-at-now already is a world clock; one place for cities.
- Tab bar: World · Sleep · Lunar · More. Lunar gets a tab (frequent glance); everything else lives in one flat More list — one tap to any tool, no nested menus, no iOS auto-More.

## Risks / open questions

- Minimum iOS 18 (needed for `ScrollPosition` / `onScrollGeometryChange` in Meetings).
- Rehearsal timer semantics assumed (countdown that keeps running as overtime). Confirm.
- Timers keep running while backgrounded by storing start date, not ticking; no background alert yet.
