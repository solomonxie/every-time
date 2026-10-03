# Boards — implementation plan

Design: [DESIGN.md](DESIGN.md) · UI: [UIUX_DESIGN.md](UIUX_DESIGN.md)

## Phase 1: Contract
Models, trailer codec and the EventKit store first — every view reads/writes through them, so views build in parallel after.

- [x] T1.1 Models + trailer codec (`BoardConfig`, `BoardColumn`, `Card`, `CardTrailer.parse/write`) + unit tests — see `EveryTime/Features/Boards` — depends: none
- [x] T1.2 `BoardStore` (@Observable): access, lists, cards per board, move/create/update/complete/delete, milestones, `EKEventStoreChanged` reload, flow snapshots; `boards.` backup prefix; Info.plist reminders key — see `EveryTime/Features/Boards` — depends: T1.1
- [x] T1.3 `AppTool.boards` in new group "Projects" + More row — see `EveryTime/Shared/AppTool.swift` — depends: none

## Phase 2: Views (parallel)
Disjoint files over the store.

- [x] T2.1 Boards list + New board sheet + access states — see `UIUX_DESIGN.md → Boards list` — depends: T1.2
- [x] T2.2 Board view (paged columns, drag & drop, Move to menu) + Card sheet + Board settings — see `UIUX_DESIGN.md → Board view` — depends: T1.2
- [x] T2.3 Roadmap + Insights (Swift Charts) — see `UIUX_DESIGN.md → Roadmap/Insights` — depends: T1.2

## Status
On hold for 1.0: `Features/Boards` and `Board*` tests are excluded in `project.yml`, and the Reminders usage string is removed. To re-enable: drop those excludes, re-add `NSRemindersFullAccessUsageDescription`, and add `AppTool.boards` (title "Boards", symbol `rectangle.split.3x1`, destination `BoardsListView()`).

## Phase 3: Finish
- [ ] T3.1 Docs (README, iphone-v1 DESIGN features, more.md), device install, walkthrough — depends: T2.*
