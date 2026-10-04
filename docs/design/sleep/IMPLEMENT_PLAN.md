# Sleep — implementation plan

Design: [DESIGN.md](DESIGN.md) · UI: [UIUX_DESIGN.md](UIUX_DESIGN.md)

## Phase 1: Model
The page is a view over `SleepNow` picks and `NapSession`; settle what a pick is and what a
tap does before touching views.

- [x] T1.1 `SleepNow.picks` — wake chips for now: night zones → whole-cycle wakes (before the usual wake first, one past it as "sleep in") + one nap; day → naps 10/20/30/90; evening → night then naps, split night `.high`. Default pick = existing `isRecommended`. Drop `bedAt` / `waitForBed` as options; keep `bedEarlier` for the "Bed by" line. Headline / button text from the pick. Update `SleepNowTests` — see `EveryTime/Features/Sleep/SleepNow.swift` — depends: none
- [x] T1.2 `NapSession` — remove `plan(bed:wake:)`, `inBedNow()`, `NightPlan`, `NapKey.night`; `start(wake:)`; `start` cancels a pending wind-down; `canCancel` (≤ 15 min) and `turnOffAlarm()` (cancel alarm, keep the sleep). Energy rating 1 / 3 / 5. Update `NapAdviceTests` — see `EveryTime/Features/Sleep/Nap/` — depends: none
- [x] T1.3 `MorningLog` — first open after the usual wake with no night logged → proposed interval (Health night if present, else usual hours); `Profile.fromHealth` median bed/wake over 14 nights — see `EveryTime/Features/Sleep/PastNights.swift` — depends: none

## Phase 2: Views
Ring first (the hero depends on its new API), then the hero, then the night-mode states which
only rearrange existing rows.

- [x] T2.1 `SleepRing` — idle: `wake: Binding<Date>`, arc from now, one alarm handle, 5-min snap, haptic detent at cycle ends; no bed handle / nap lane / pin / summary / actions; remove `sleep.ring.*` keys and `waiting`. Asleep: dim variant, cycles in the centre — see `UIUX_DESIGN.md → Components/Ring` — depends: none
- [x] T2.2 `SleepHero` (new file) — headline (tap → inline time wheel) + fit line + ring + wake chips + verdict + warning + hours line; bottom bar `Sleep now` / `Nap now` with `Remind me` in the evening; replaces `SleepRing(now:profile:)` in `SleepTimeView.hero` — see `UIUX_DESIGN.md → Idle` — depends: T1.1, T1.2, T2.1
- [x] T2.3 `NightScreen` — asleep / ringing / just up on a black page: big clock, alarm line, one verdict line, `UP AT` chips, `SLEEP MORE` chips, 3-button feel; bar per state; lower sections not rendered; `UIScreen.main.brightness` lowered on appear, restored on leave — see `UIUX_DESIGN.md → Asleep, Ringing, Just up` — depends: T1.2
- [x] T2.4 Morning card in idle; "Use hours from Health" line — see `UIUX_DESIGN.md → Morning card, States` — depends: T1.3, T2.2
- [x] T2.5 Launch on Sleep while a sleep is active — see `EveryTime/Shared/AppTool.swift` — depends: T1.2

## Phase 3: Cleanup and verify
- [x] T3.1 Remove dead code: `AsleepCard` / `WokeCard` / `LadderRow` / `SleepPlan.wakeTimes(includesNap:)` once `NightScreen` replaces them — depends: T2.3
- [ ] T3.2 On-device pass in the dark: S1, S5, S6, S7 at real hours, alarm through silent mode, brightness restore; `make device` — depends: T2.*
- [ ] T3.3 Refresh `docs/release/screenshots/02-sleep.jpg`; `demo/sleep.json` still seeds — depends: T3.2

## Phase 4: Zero-tap entries (later)
Lock screen does the work; the app isn't opened at all.

- [ ] T4.1 Live Activity while asleep: alarm time, cycles done, `I'm up` — depends: T2.3
- [ ] T4.2 AlarmKit snooze = `+1 cycle`; pre-26 notification action `Sleep 20 more` — depends: T1.2
- [ ] T4.3 Bedtime reminder notification carries `Sleep now · up at {time}` — depends: T1.2
- [ ] T4.4 Control Center control + App Intent "Nap 20 min" / "Sleep now" — depends: T1.2
