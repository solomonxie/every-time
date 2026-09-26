# Sleep

Two separate tools: **Sleep** (cycles) and **Jet lag planner** (tab label
"Jet lag"). The trip timeline (`JetLagPlanView`) is unchanged.

## Cycles

```
Sleep
╭─────────────────────────────────╮
│ [ WAKE AT | Sleep now ]         │
│ 6:30 AM                       › │ ← hero clock; tap → wheel unfolds in card, › → ⌄
│ Tomorrow · in 6h 39m            │
╰─────────────────────────────────╯
GO TO BED AT ⓘ
╭─────────────────────────────────╮
│ 9:15 PM       ▮▮▮▮▮▮      9h    │ ← one bar segment per cycle, of 6
│ 10:45 PM      ▮▮▮▮▮      7.5h   │   5-6 cycles: accent bars, primary text
│ 12:15 AM      ▮▮▮▮        6h    │
│ 1:45 AM       ▮▮▮        4.5h   │
╰─────────────────────────────────╯
```
```
sleep now   hero = current time, "Asleep by ~12:06 AM"; list = WAKE UP AT
passed      bedtime already behind now: dimmed, struck through
```
- Wake time and mode persist (`sleep.cycles.*`); wake = next occurrence.
- ⓘ → "A cycle is ~90 min… includes ~15 min to fall asleep."

## Jet lag planner: trips

```
Jet lag
YOUR SLEEP
╭─────────────────────────────────╮
│ 11:00 PM → 7:00 AM     8h     › │ ← profile card replaces toolbar ⚙
│ In between · Caffeine · Reminders│
╰─────────────────────────────────╯
UPCOMING
 ✈ Tokyo → London             Oct 3
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
│                          ⇅ Swap │
╰─────────────────────────────────╯
FLIGHT
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
╰─────────────────────────────────╯
[[           Create plan          ]]
```
```
invalid   ⚠ Arrival is before departure   [[ Create plan ]]· dimmed
no dest   [[ Create plan ]]· dimmed
```
