# Every Time — iPhone v1 design

UI: [UIUX_DESIGN.md](UIUX_DESIGN.md) · Build: [IMPLEMENT_PLAN.md](IMPLEMENT_PLAN.md)

## Problem

Time utilities are scattered across many apps: world clock, meeting planner,
practice timers, sleep calculator, dev timestamp tools. Each is small, ad-laden
or paid. One free app should cover them all.

## Goals

- Every tab does real work offline — no placeholder screens in v1 except Wait times.
- User data (cities, timer history, anniversaries) persists on device.
- Zero accounts, zero network for v1 features.

## Non-goals (v1)

- Widget and Watch — targets stay as stubs until the phone app is solid.
- Wait times live data — no free, reliable public wait-time API found yet.
- "On this day" — needs a network source (Wikipedia feed); v2.
- Lunar birthday push notifications — v1 shows next occurrence only; alerts v2.
- iCloud sync, iPad layout, landscape.

## Features

| Tab | v1 scope |
|---|---|
| Timers (More) | Stopwatch (laps), Interview countdown, Rehearsal (count down a talk slot, then count up overtime), LeetCode timer + persisted history |
| Countdown (More) | countdowns to a date/time: focus unit biggest (days → hours → minutes → seconds), sideways full screen, fireworks/confetti + sound + vibration at zero, optional notification |
| World (tab 1) | World Time Buddy–style (merged world clock + meeting planner): pinned cities, shared horizontal hour scroll across a week, center cursor, now marker, tappable overlap |
| Sleep | bedtimes for a wake time, and wake times for "sleep now" — 90-min cycles + 15-min fall-asleep |
| Jet lag planner | own tool (was a Sleep segment): per-trip light/sleep/caffeine/melatonin plan — `docs/design/jet-lag/` |
| Wait times (More) | sample data only |
| Lunar (tab) + Important events (More) | important events (manual or picked from iPhone Calendar, typed: birthday, anniversary, memorial…) with time since, next anniversary and a yearly 9:00 reminder; lunar date converter + lunar anniversaries' next Gregorian date |
| Dev tools (More) | live Unix timestamp, timestamp ⇄ date converter, cron expression parser (next runs) |

## Options considered

- Persistence: SwiftData vs Codable JSON in UserDefaults → **JSON/UserDefaults**. Data is tiny (dozens of rows), no queries; avoids schema migrations and keeps the widget/watch able to read it later via an App Group.
- Lunar math: own tables vs `Calendar(identifier: .chinese)` → **Foundation**. Built-in, correct, no data files.
- Cron: library vs own parser → **own parser**. Standard 5-field syntax is ~150 lines; no SPM dependency.
- Separate Clocks list + Meetings planner vs one screen → **merged into World**. The planner's cursor-at-now already is a world clock; one place for cities.
- Tab bar: World · Sleep · Lunar · More. Lunar gets a tab (frequent glance); everything else lives in one flat More list — one tap to any tool, no nested menus, no iOS auto-More.

## Risks / open questions

- Minimum iOS 18 (needed for `ScrollPosition` / `onScrollGeometryChange` in Meetings).
- Rehearsal timer semantics assumed (countdown that keeps running as overtime). Confirm.
- Timers keep running while backgrounded by storing start date, not ticking; no background alert yet.
