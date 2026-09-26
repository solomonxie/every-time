# Every Time — iPhone v1 implementation plan

Design: [DESIGN.md](DESIGN.md) · UI: [UIUX_DESIGN.md](UIUX_DESIGN.md)

## Phase 1: Shared foundation
Persistence and the city picker are used by several tabs; land them first so feature work runs in parallel without touching shared files.

- [x] T1.1 `Stored<T>` Codable JSON in UserDefaults — see `EveryTime/Shared` — depends: none
- [x] T1.2 City picker sheet + `WorldCity` model — see `uiux/clocks.md → City picker` — depends: none

## Phase 2: Features
Disjoint feature folders, one agent each.

- [x] T2.1 Clocks list (superseded by T2.2 World) — see `uiux/clocks.md` — depends: T1.1, T1.2
- [x] T2.2 World (Clocks + Meetings merged): World Time Buddy grid, center cursor, overlap jump — see `uiux/world.md` — depends: T1.1, T1.2
- [x] T2.3 Timers: stopwatch, interview, rehearsal, LeetCode + history — see `uiux/timers.md` — depends: T1.1
- [x] T2.4 Sleep: cycle math both modes — see `uiux/sleep.md` — depends: none
- [x] T2.5 Tools: unix clock, converter, cron parser — see `uiux/tools.md` — depends: none
- [x] T2.6 Calendar: important events, lunar converter + lunar dates — see `uiux/calendar.md` — depends: T1.1

## Phase 3: Layout and v1 extras
Driven by first on-device use: fewer tabs, planner first, lunar events and backups.

- [x] T3.1 Tabs: World · Sleep · Lunar · More (flat list) — see `uiux/more.md` — depends: T2.*
- [x] T3.2 World: drag reorder, edit/remove, bottom bar (Now, Edit, Add) — see `uiux/world.md` — depends: T3.1
- [x] T3.3 Lunar events: bottom Add button, repeat, export to iPhone Calendar — see `uiux/calendar.md` — depends: T3.1
- [x] T3.4 Settings: iCloud Drive + local zip backups, import/export, first-run restore — see `uiux/settings.md`, `EveryTime/Backup/README.md` — depends: T3.1
- [x] T3.5 Timers full-screen sideways clock — see `uiux/timers.md` — depends: none
- [x] T3.6 App icon — see `scripts/make_icon.swift` — depends: none

## Phase 4: Redesign and personalisation
Driven by device use: one visual language, user-chosen tab bar, richer dates.

- [x] T4.1 Visual language + shared components — see `uiux/visual.md`, `EveryTime/Shared/Theme.swift` — depends: none
- [x] T4.2 Custom tab bar (1–4 pins + More), inline Settings, shared TimerStore — see `uiux/more.md` — depends: T4.1
- [x] T4.3 Redesign World, Timers (Rehearsal rename), Tools, Lunar, Wait times — see `uiux/*.md` — depends: T4.1
- [x] T4.4 Jet lag planner in Sleep — see `docs/design/jet-lag/` — depends: T4.1
- [x] T4.5 Important events (calendar search, types, yearly reminders) — see `uiux/calendar.md` — depends: T4.1

## Phase 5: Polish
- [ ] T5.1 Unit test target for pure logic (sleep math, cron, lunar occurrences, backup snapshot/zip) — depends: T3.*

## Later (v2)
- [ ] Waiting data source · On this day · lunar notifications · widget · watch · App Group sharing
