# Sleep

Two separate tools: **Sleep** (cycles) and **Jet lag planner** (tab label
"Jet lag"). The trip timeline (`JetLagPlanView`) is unchanged.

## Sleep time (`SleepTimeView`)

One question, answered top-down: *if I sleep now, what happens?* → pick an
option → act. Then tonight's plan, reference info, the nap log, and how it works.

```
                 When to sleep?
If I sleep now                              ⓘ  ← largeTitle; "at 3:15 PM" when offset
[ NOW | In 15 min | In 30 min | In 1 h ]       ← segmented, replaces the menu
Good time for a nap                            ← verdict, title2
20 min refreshes without grogginess.           ← reason, secondary

YOUR OPTIONS                                ⓘ  ← ⓘ = colour + timeline legend
╭──────────────────────────────────────────╮
│ ◉ Nap 20 min   BEST            wake at   │  ← trailing caption says what the time is
│                                3:40 PM   │
│   🌙 Little effect on tonight        ●   │  ← effect rows, own colour dot each
│   ☀ Wake up fresh                   ●   │
│   ▓▓░░░░░░░░░░░░░░░│████████████         │  ← timeline
│   3:15 PM       bed 11:00 PM    7:00 AM  │
│   ▓ Nap  █ Sleep  ▒ Slow to fall asleep  │  ← legend: only kinds shown
├──────────────────────────────────────────┤
│ ○ Nap 90 min                   wake at   │
│                                4:45 PM   │
├──────────────────────────────────────────┤
│ ○ Nap 10 min                   wake at   │
╰──────────────────────────────────────────╯
Can't fall asleep after ~20 min? …           ← tip, late night only

TONIGHT                              ⓘ  ( Use usual )   ← only when changed
╭──────────────────────────────────────────╮
│ 🛏 Bed                        11:00 PM › │  ← wheel unfolds in place
│ ⏰ Wake                        7:00 AM › │
│ 😴 Sleep                  8h · 5 cycles  │
│ 💡 Late night — a 90-minute nap …        │
╰──────────────────────────────────────────╯

TODAY'S GUIDE
╭──────────────────────────────────────────╮
│ Best nap window  ⓘ      1:00 – 3:30 PM   │
│ Bedtimes  ⓘ          for 7:00 AM wake ›  │  ← unfolds the cycle list
│ Usual sleep  ⓘ          11:00 PM – 7:00 › │  ← profile sheet
╰──────────────────────────────────────────╯

NAPS  ⓘ                                       ← ⓘ: why rate nights
┌ How was the night after Tue's 20-min nap? ┐
│ [😊 Slept well] [⌛ Took longer] [☔ Poorly]│
└───────────────────────────────────────────┘
● Tue, Sep 22   2:10 – 2:30 PM   😊   20 min
YOUR NIGHTS AFTER NAPS (3+ rated)
● Little effect on tonight      4 of 5 good

HOW THIS WORKS                                ← plain footnote text, bottom of page
• A sleep cycle is ~90 min; waking between cycles is easier; 5–6 cycles = a full night.
• Wake times include ~15 min to fall asleep.
• ● green little effect · ● orange some · ● red likely to hurt tonight / groggy.
• Rough guide, not medical advice.

[ + Add past nap ]                 [ 🌙 Nap 20 min · 3:40 ]   ← bottom bar, soft pills
```

Bottom bar right pill = the selected option's action:
```
nap selected        🌙 Nap 20 min · 3:40         → starts nap + alarm
bed-earlier chosen  🛏 Plan bed 10:30            → sets tonight's bed
night option        ⏰ Plan wake 6:45            → sets tomorrow's wake
otherwise           🌙 Nap ▾                     → menu 10/20/30/90
napping             ( Cancel )  [[ I'm up ]]     ← NapInProgress replaces the top
```

ⓘ texts: If I sleep → what the page does; Options → colours + timeline; Tonight → plan vs usual; Nap window → post-lunch dip, ends before bedtime pressure; Bedtimes → cycle maths; Usual sleep → used for every calculation; Naps → rating builds your own pattern.

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
