# Sleep

Two separate tools: **Sleep** (cycles) and **Jet lag planner** (tab label
"Jet lag"). The trip timeline (`JetLagPlanView`) is unchanged.

## Sleep time (`SleepTimeView`)

Plan first, then choices, then what a choice does; naps last.

```
                 When to sleep?
TOMORROW                                    ⓘ
╭──────────────────────────────────────────╮
│ ⏰ Wake up                     7:00 AM › │  ← wheel unfolds in place
│ 🛏 Bed tonight                11:00 PM › │
│ 😴 Sleep length          8h · 5 cycles   │
│ 💡 Late night — a 90-minute nap …        │
│ ↺ Back to usual · 11:00 PM – 7:00 AM     │  ← only when changed; undoes Plan bed/wake
│ Changed for tonight only.                │
╰──────────────────────────────────────────╯
YOUR OPTIONS                                ⓘ  ← colours; changes follow the plan
╭──────────────────────────────────────────╮
│ ◉ Nap 20 min   BEST        wake at    ●  │  ← tap again = back to Best
│                            3:40 PM       │
│ ○ Nap 90 min               wake at    ●  │
╰──────────────────────────────────────────╯
TODAY'S GUIDE
│ Best nap window ⓘ         1:00 – 3:30 PM │
│ Bedtimes ⓘ                best 10:45 PM ›│
│ Usual sleep ⓘ          11:00 PM – 7:00 › │

If I sleep now                              ⓘ  ← largeTitle
[ NOW | In 15 min | In 30 min | In 1 h ]
Good time for a nap
20 min refreshes without grogginess.
╭──────────────────────────────────────────╮
│ Nap 20 min                wake at 3:40 PM│  ← the picked option
│ 🌙 Little effect on tonight              │
│ ☀ Wake up fresh                          │
│ ▓▓░░░░░░░░│██████████   + legend          │
│ ( ⏲ Start 20-min nap )                   │  ← or Use as tonight's bed / tomorrow's wake
╰──────────────────────────────────────────╯

HOW THIS WORKS   • cycles • 15 min • colours • backup alarm • not medical advice

NAPS                                        ⓘ
( + Add past nap )  ( ⏲ Start a nap ▾ )        ← 10/20/30/90 min
rate prompt · nights-after-naps pattern · list
```

No fixed bottom bar, except while napping: `( Cancel )  [[ I'm up ]]` with NapInProgress at the top.

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
