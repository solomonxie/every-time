# Sleep

Two separate tools: **Sleep** (cycles) and **Jet lag planner** (tab label
"Jet lag"). The trip timeline (`JetLagPlanView`) is unchanged.

## Sleep time (`SleepTimeView`)

One answer for right now, picked by the time of day. Read the headline, tap the button.

```
                 When to sleep?                  ⓘ  ← sheet: How this works
╭──────────────────────────────────────────╮
│ Good time for a nap                      │  ← verdict for now
│ 20 min refreshes without grogginess.     │
│                                          │
│ Wake at                                  │
│ 2:20 PM                                  │  ← the picked option
│ 💤 Little effect on tonight              │
│ ☀ Wake up fresh                          │
│ [[ ⏰ Start 20-min nap ]]                │
│                                          │
│ ●Nap 10 min [●NAP 20 MIN] ●Nap 30 min    │  ← chips wrap; ● = effect colour;
│ ●Nap 90 min                              │     tap swaps the block above; hidden if one
╰──────────────────────────────────────────╯
TONIGHT
╭──────────────────────────────────────────╮
│ 🛏 Bed          ⏰ Wake up             ›  │  ← tap: night dial
│ 11:00 PM   →    7:00 AM                   │
│ 8h · 5 cycles  ✓ Wakes between cycles     │  ← orange ! when mid-cycle
│ Changed for tonight                       │  ← only when changed
│ 👤 Set your usual sleep hours             │  ← only until set
╰──────────────────────────────────────────╯
LAST NAP                                       ← unrated nap from a past day
How was the night after Monday's 20-minute nap at 2:00 PM?
( 😊 Slept well ) ( ⏳ Took longer ) ( 🌧 Slept poorly )
PAST NIGHTS ⓘ                                ← from Health; button until allowed
Average asleep                          7h 20m  ← 3+ nights
Sun, Sep 28   11:10 PM – 6:50 AM · 5 cycles   7h 25m
NAPS                                      ⊕  ← Add past nap
● Little effect on tonight          3 of 4 good ← pattern rows, 3+ rated
Mon, Sep 28   2:00 – 2:20 PM       😊   20 min  ← long-press: rate / clear
Show all 12
```

Answer card by time of day (chips: `*` = best):

```
morning   Early for a nap
          If you can't wait, keep it to 20 min.
          *Nap 20 · Nap 10 · Nap 30 · Nap 90
evening   Close to bedtime
          Stay up until 9:45 PM, or make it an early night.
          Bed at → 9:45 PM · 🛏 6 cycles (9h) before your 7:00 AM wake
          [ 🛏 Make 9:45 PM tonight's bed ]           ← hidden once it is
          *Bed at 9:45 PM · Sleep now · Nap 10 · Nap 20 · Nap 30
6 PM      Risk of a split night                     ← "Sleep now" chip is red
          Sleep for the night now and you'll likely wake around 10:45 PM…
bedtime   Bedtime
          Asleep by ~11:15 PM.
          Wake at → 6:45 AM · ⏰ 5 full cycles
          [ ⏰ Make 6:45 AM tomorrow's wake ]
          Sleep 9h · *Sleep 7h 30m · Sleep 6h · Sleep 4h 30m
late      Past bedtime
          Wake times that still fit before 7:00 AM.
          💡 Can't fall asleep after ~20 minutes? …   ← footnote
napping   card replaced by the countdown ring (below)
```

**Past nights**: last 14 days of Health sleep; Watch/iPhone overlaps merged, split on 2 h awake,
longest ≥ 3 h per wake day (naps dropped). Falls back to in-bed when no asleep samples.

**Night dial** (pushed "Tonight"): Bed / Wake readouts, 24 h dial (midnight on top) —
drag 🛏 or ⏰ handle, or the arc to move both; 5-min snap, 3–14 h, dots at cycle ends,
length + cycles in the centre. Chips: bedtimes for 6/5/4 cycles. Back to usual.
`Change usual hours…` opens the profile sheet. Applies live, one night.

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
