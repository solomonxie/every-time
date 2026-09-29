# Sleep

Two separate tools: **Sleep** (cycles) and **Jet lag planner** (tab label
"Jet lag"). The trip timeline (`JetLagPlanView`) is unchanged.

## Sleep time (`SleepTimeView`)

Plan, then "If I sleep now" and "If I nap now" — nap first during the day, sleep first from evening.

```
                 When to sleep?
TONIGHT                                     ⓘ
╭──────────────────────────────────────────╮
│ 🛏 Bed          ⏰ Wake up             ›  │  ← tap: night dial
│ 11:00 PM   →    7:00 AM                   │
│ 8h · 5 cycles  ✓ Wakes between cycles     │  ← orange ! when mid-cycle
│ ✨ Bed at 11:15 PM wakes you between…     │  ← one-tap fix, mid-cycle only
│ 💡 Short night — …                        │
│ Changed for tonight          Back to usual│  ← only when changed
│ Usual sleep ⓘ        11:00 PM – 7:00 AM › │
╰──────────────────────────────────────────╯
If I sleep now ⌄                            ⓘ  ← menu: Now / In 15 / 30 min / 1 h
Bedtime
Asleep by ~11:22 PM.
╭──────────────────────────────────────────╮
│ ◉ Sleep 7h 30m  BEST       wake at    ●  │  ← picked row opens: effect + timeline
│ ○ Sleep 6h                 wake at    ●  │     daytime: no options, "Too early for bed"
╰──────────────────────────────────────────╯
( ⏰ Use as tomorrow's wake )                   ← or Use as tonight's bed
If I nap now                                ⓘ  ← always now
Good time for a nap
20 min refreshes without grogginess.
Nap window                    1:00 – 3:45 PM
[────████───│──────────]                       ← wake → bed, window, now line
╭──────────────────────────────────────────╮
│ ○ Nap 10 min … ◉ Nap 20 min BEST … 90    │  ← none picked when all are bad
╰──────────────────────────────────────────╯
[[ ⏰ Start 20-min nap ]]
PAST NIGHTS ⓘ                                ← from Health; button until allowed
Average asleep                          7h 20m  ← 3+ nights
Sun, Sep 28   11:10 PM – 6:50 AM · 5 cycles   7h 25m
NAPS ⓘ                                   ⊕  ← Start a nap ▸ / Add past nap
rate prompt · pattern · list · How this works

```

**Past nights**: last 14 days of Health sleep; Watch/iPhone overlaps merged, split on 2 h awake,
longest ≥ 3 h per wake day (naps dropped). Falls back to in-bed when no asleep samples.

**Night dial** (pushed "Tonight"): Bed / Wake readouts, 24 h dial (midnight on top) —
drag 🛏 or ⏰ handle, or the arc to move both; 5-min snap, 3–14 h, dots at cycle ends,
length + cycles in the centre. Chips: bedtimes for 6/5/4 cycles. Back to usual. Applies live, one night.

**Napping**: countdown ring + alarm time, tonight's effect, alarm status
(silent-mode note, low volume, notifications off). Bar: `( Cancel nap )  [[ ☀ I'm up ]]`.

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
