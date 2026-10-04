# Sleep

Two separate tools: **Sleep** (cycles) and **Jet lag planner** (tab label
"Jet lag"). The trip timeline (`JetLagPlanView`) is unchanged.

## Sleep time (`SleepTimeView`)

Redesigned — see [docs/design/sleep/](../../sleep/UIUX_DESIGN.md).

**Past nights**: last 14 days of Health sleep; Watch/iPhone overlaps merged, split on 2 h awake,
longest ≥ 3 h per wake day (naps dropped). Falls back to in-bed when no asleep samples.

**Alarm**: iOS 26+ AlarmKit. Earlier: app rings itself via playback audio (ignores
silent switch; muted loop keeps it alive in background), plus 8 notifications 30 s
apart with a 29 s sound as backup if swiped away. "I'm up" on the lock-screen banner logs the nap.

## Jet lag planner: trips

```
Jet lag
YOUR SLEEP
╭─────────────────────────────────╮
│ 11:00 PM → 7:00 AM     8h     › │ ← profile card replaces toolbar ⚙
│ In between · Caffeine · Reminders│
╰─────────────────────────────────╯
UPCOMING
 ✈ Tokyo → London             Oct 3   ← full route when multi-leg
   Starts in 3 days             −8h
PAST
 …
[[        ✈ Plan a trip        ]]
```
```
no profile   │ Set up your sleep          › │
             │ Usual hours shape every plan │
no trips     No trips yet — light, sleep and caffeine timing.
```

## Your sleep (profile sheet)

```
Cancel          Your sleep
╭─────────────────────────────────╮
│ 11:00 PM → 7:00 AM         8h   │ ← live readout
│ Bedtime              11:00 PM › │ ← tap → wheel unfolds in place
│ Wake up               7:00 AM › │   one open at a time
╰─────────────────────────────────╯
CHRONOTYPE ⓘ
│ sunrise  Early     Up and sleepy early    │
│ sun      In between                     ✓ │
│ moon     Late      Up and sleepy late     │
ABOUT YOU ⓘ                          ← ⓘ: why age/sex matter
│ Age                            35 › │ ← wheel unfolds
│ Sex                Not specified ⌄ │ ← menu
ADVICE
│ cup      Caffeine timing        ─● │
│ pill     Melatonin ⓘ            ○─ │
│ bell     Reminders              ─● │
[[             Save              ]]
```

## New trip

```
Cancel           New trip
╭─────────────────────────────────╮
│ From      San Francisco       › │ ← city picker sheet (searches a corpus)
│ To        Tokyo               › │
│ + Add a flight           ⇅ Swap │ ← swap only with one flight; max 4
╰─────────────────────────────────╯
FLIGHT                              ← "FLIGHT n   Remove" when multi-leg
│ Stopover in Tokyo         3h      │ ← flights 2+
│ Departs                  Oct 1, 6:00 PM › │ ← date+time wheel unfolds
│   San Francisco time                      │
│ Arrives                  Oct 2, 9:00 PM › │
│   Tokyo time                              │
│ In the air                       11h      │
START ADJUSTING ⓘ
│ [ Day of | 1 DAY | 2 days | 3 days ] │ ← before departure
╭─────────────────────────────────╮
│ +16h east                       │ ← plan preview, clock font
│ Advancing · about 6 days        │
│ Tokyo time, then Singapore time │ ← multi-leg; or "Short stopover — straight to X time"
╰─────────────────────────────────╯
[[           Create plan          ]]
```
```
invalid   ⚠ Arrival is before departure   [[ Create plan ]]· dimmed
          ⚠ Flight 2 departs before flight 1 lands
no dest   [[ Create plan ]]· dimmed
```
