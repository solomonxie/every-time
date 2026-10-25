# Labor — implementation plan

Why: [DESIGN.md](DESIGN.md) · UI: [UIUX_DESIGN.md](UIUX_DESIGN.md)

## Phase 1: Model and analysis
The pure rules come first. The UI only renders them, and tests pin them before any screen exists.

- [x] T1.1 Models — `Contraction`, `LaborEvent`, `LaborSettings`, `LaborRule` presets, keys — see `EveryTime/Features/Labor/` — depends: none
- [x] T1.2 `LaborAnalysis` — episode, clean data, window stats, trend, go rule, pattern + reasons, red flags, summary text — see `DESIGN.md` — depends: T1.1
- [x] T1.3 Tests — `EveryTimeTests/LaborAnalysisTests.swift`: BH vs labor, 5-1-1 edges, mis-taps, preterm, NHS flags, episode gap — depends: T1.2

## Phase 2: Screen
Built on the analysis, in one file set so there are no parallel collisions.

- [x] T2.1 `LaborView` — hero, Start/Stop, strength, cards, events, history, edit sheet, settings sheet, share, call, screen awake — depends: T1.2
- [x] T2.2 Wire up — `AppTool.labor`, More live value, backup counted keys, README line — depends: T2.1
- [x] T2.3 Setup — `LaborSetup`, plan derived from answers (`LaborSettings.plan`), Later → "Finish setup" row — depends: T1.1
- [x] T2.4 Profiles — one per labor, switch/add/rename/delete, "Start over" after a birth, migration at launch and restore — depends: T1.1
- [x] T2.5 Stages — bar, preview, suggestions with a saved "Not yet", birth card — depends: T1.2
- [x] T2.6 Pregnancy card — weeks, ACOG term, tip, get-ready checklist — depends: T2.3
- [x] T2.7 Review fixes — red flags first, goal hints and met state, undo, event time editing, overlap check, battery and screen awake — depends: T2.1–T2.6

## Phase 3: Verify
- [x] T3.1 Unit tests pass on device, `make build`, then `make device` — depends: T1.3, T2.7
