# Jet lag planner — implementation plan

## Phase 1: Contract
Model types + planner signature first, so engine and UI build in parallel.

- [x] T1.1 `JetLagModels.swift` (Profile, Trip, Plan, PlanDay, Action) + stub `JetLagPlanner.plan` — see `EveryTime/Features/Sleep/JetLag` — depends: none

## Phase 2: Engine + UI (parallel)

- [x] T2.1 Planner per DESIGN model table; verified by a standalone script over sample trips (east/west/12h/same-tz) — depends: T1.1
- [x] T2.2 UI: Cycles/Jet lag switch, trips list, profile + new-trip sheets, plan timeline, popovers — depends: T1.1
- [x] T2.3 Notifications: schedule next 60 actions, reschedule on launch/foreground, per-trip toggle — depends: T1.1

## Phase 3
- [ ] T3.1 Install on device, walk through a sample trip — depends: T2.*
- [ ] T3.2 Multi-leg trips; flight-number lookup (needs a flight data API, e.g. AeroDataBox) (v2)
