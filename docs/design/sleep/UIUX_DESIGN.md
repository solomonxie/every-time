# Sleep — UI/UX

Why: [DESIGN.md](DESIGN.md) · Stories: [STORIES.md](STORIES.md). One tab page, `SleepTimeView`; nothing pushed.

## Glance rules — every state must pass

```
✓  3 lines, biggest type, top of the page:   what time · what's happening · what the one button does
✓  ≤ 2 buttons per state; the primary always in the bottom bar, same spot in every state
✓  looking never changes anything; "go back to sleep" = 0 taps
✓  asleep / ringing / just up: black page, warm dim text, screen brightness lowered,
   nothing below the fold
✓  numbers first, no hedges in headlines: "Up at 6:35", not "Asleep by ~11:35, 5 cycles end at…"
✗  two buttons that both stop the noise (Cancel next to I'm up while ringing)
```

## Screen map

```
Launch ── sleep active ──▶ Sleep tab, Asleep (whatever tab was last)
Sleep ─ idle ──Sleep now──▶ asleep ──alarm──▶ ringing ──I'm up──▶ just up ──rate / 2 h──▶ idle
          │  └──Bed at B──▶ waiting ──at B──▶ asleep (Cancel from either keeps B and the wake set)
          │                   │ Cancel (first 15 min)                 │
          │                   └──────────────────────────────── idle ◀┘   I'm up also from the
          ├─ Remind me… ──▶ [notification at bed − 30 min]                [lock-screen banner]
          ├─ ⓘ ──▶ popover (how cycles work)
          ├─ morning card ──▶ logs last night in place
          └─ Change (footer) ──▶ Your sleep (profile sheet, unchanged)
```

Only the hero changes state. Below it, idle only: Nights, Naps, then Insights (sleep debt, energy,
trend chart) and the footer. The old Today tiles (coffee, energy, debt) are gone — the coffee cutoff
is on the ring, the rest moved to Insights.

```
INSIGHTS
╭──────────────────────────────────────────╮
│ 🛏 Sleep debt ⓘ                   2h 10m  │   ← green < 1 h · orange < 3 h · red
│    Short of 8 h/night over the last 7    │
│ ⚡ Energy ⓘ                       3.8 / 5 │   ← mean of recent feel ratings
│    How you felt waking, recently         │
│ Sleep score                              │   ← 2+ nights
│  ▂▅▇▆▃▇▇                                 │
│ Energy on waking                         │   ← 2+ ratings; both charts, no tabs
│  ▃▅▅▇▆                                   │
╰──────────────────────────────────────────╯
```

## Idle — night (S1, S3)

```
                        Sleep                              ⓘ
   🛏 BEDTIME                  ⏰ WAKE UP                      ← two readouts; tap either → wheel
   11:20 PM ⌄                  6:40 AM ⌄                         unfolds under them (one at a time),
                                                                  10-minute steps
   Now                         Tomorrow
 7h 15m · 5 cycles · wakes between cycles ✓                    ← green / orange / red (WakeFit)

            ╭──────────── 12 AM ────────────╮
            │     ·  ·  cycle ticks  ·  ·   │                 ← 24 h face, midnight on top
     9 PM   │  🛏11:20 PM ━━━━━━━━━━◉ 6:35  │   3 AM          🛏 bed handle (now, or dragged later)
            │        7h 15m · 5 cycles      │                 ◉ alarm handle: 10-min steps, haptic
     6 PM   │   ░░ deep-sleep shading ░░    │   6 AM             detent at every cycle end from bed
            ╰──────────── 12 PM ────────────╯

 [ 5:05 AM ] [[ 6:35 AM ]] [ 8:05 AM ]                         ← cycle ends from bed; tap → arc, button
   4 cycles   5 · best      6 · sleep in
 Bedtime — asleep by about 11:35 PM.                           ← SleepNow verdict, secondary
 ⚠ Alarm can't ring — notifications are off · Turn on         ← only when true; before the tap
 Usually 11:00 PM – 7:00 AM · Set your hours                   ← only until the profile is set
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 [[            🌙  Sleep now · up at 6:35 AM            ]]      ← bottom bar; 1 tap → Asleep
```

Bed and wake stay where you put them (chip, wheel or drag) until they pass; the pick for now
only fills in a wake you haven't set. Chips are cycle ends from the bed time.

## Idle — bed later (S10)

```
9:00 PM    🛏 BEDTIME                  ⏰ WAKE UP
           11:00 PM ⌄                  6:35 AM ⌄              ← bed dragged / set later than now
           Today                       Tomorrow
         7h 35m · 5 cycles · wakes between cycles ✓
           ( ring: 🛏 at 11:00 PM, arc to ◉ 6:35 )
         [ 5:05 AM ] [[ 6:35 AM ]] [ 8:05 AM ]                  ← from the 11:00 PM bed
         [[ 🛏 Bed at 11:00 PM · up at 6:35 AM ]]               ← 1 tap → Planned

tap ↓    Waiting — the night screen, black, counting down to bed
                         9:02 PM
                  Bed 11:00 PM · in 1h 58m
                   Alarm 6:35 AM is set                        ← last 30 min: "Wind down · lights low, screens away"
           ( ring: 🛏 11:00 PM → ◉ 6:35, centre "1h 58m until bed" )
         Asleep from 11:00 PM unless you tap below first; up at 6:35 AM.
         ( Cancel )           [[ 🌙 Asleep already ]]           ← at 11:00 PM it becomes Asleep by itself;
                                                                  Cancel → idle with 11:00 / 6:35 still set
```

## Idle — day (S2, S4)

```
 Up at 2:30 PM
 20-min nap · wakes before deep sleep ✓
            ╭──────────── 12 AM ────────────╮
            │        ▌2:10 PM ◉ 2:30        │
            ╰──────────── 12 PM ────────────╯
 [ 2:20 PM ] [[ 2:30 PM ]] [ 2:40 PM ]! [ 3:40 PM ]
   10 min     20 · best     30 · groggy   90 · full cycle
 Good time for a nap — little effect on tonight. Coffee OK until 3:00 PM.
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 [[            ☕  Nap now · up at 2:30 PM              ]]
```

## Idle — evening / late (S9, S11)

```
9:00 PM  BEDTIME 9:00 PM Now · WAKE UP 6:15 AM
         9h 15m · 6 cycles · wakes between cycles ✓
         [[ 6:15 AM ]]
           6 · best
         Close to bedtime — bed by 11:05 PM for 5 cycles.    ← drag 🛏 there to plan it
         [[ 🌙 Sleep now · up at 6:15 AM ]]

7:00 PM  Up at 7:20 PM
         20-min nap · wakes before deep sleep ✓
         [ 7:10 PM ] [[ 7:20 PM ]] [ 6:45 AM ]!
         Risk of a split night — sleep for the night now and you'll likely wake ~11:45 PM.   ← red
         [[ ☕ Nap now · up at 7:20 PM ]]

1:30 AM  Up at 6:15 AM
         3 cycles · wakes between cycles ✓
         [ 4:45 AM ] [[ 6:15 AM ]] [ 7:45 AM ] [ 1:50 AM ]
           2           3 · best     4 · sleep in  Nap 20
         Past bedtime. Can't fall asleep after ~20 min? Get up in dim light, no screens.
         [[ 🌙 Sleep now · up at 6:15 AM ]]
```

## Asleep — night mode (S5, S7, S8)

```
 ■■■■■■■■■■■■■■■■■■■ black · brightness lowered ■■■■■■■■■■■■■■■■■■
                         3:12 AM                               ← ~72 pt, warm grey
                  Alarm 6:35 · in 3h 23m                       ← title2
          Mid-cycle · sleep on, 3:50 feels better              ← one line, amber
                                                                  green: "Between cycles · OK to get up"
                                                                  first 15 min: "Just dozed off"
            ╭───────────────────────────────╮
            │   ●●○○○  2 of 5 cycles        │                 ← dim ring, arc fills with time
            ╰───────────────────────────────╯
 [ Up at 3:50 ] [ 5:20 ] [ 6:35 ✓ ] [ 8:05 ]                   ← dim chips; tap moves the alarm
 Rings in silent mode and Focus.                               ← dim footnote; pre-iOS 26 warnings here
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 ( Cancel )                          [[ ☀ I'm up ]]            ← Cancel only in the first 15 min
```

- Go back to sleep = lock the phone. Nothing to tap.
- Cancel (≤ 15 min, S8): drops the sleep, toast `Nap cancelled · Undo`. After 15 min the bar
  has `I'm up` alone; `Alarm 6:35 ⌄` holds `Turn off alarm` (keeps the sleep logged).
- Nothing scrolls; the lower sections are not rendered while asleep.
- Brightness: lowered to ~0.2 on entering, the user's value restored on leaving the state.

## Ringing (S6, S7)

```
 ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
                         6:35 AM
                       Get up ☀                                ← orange, haptic every few seconds
                 7h 13m · 5 cycles ✓
 [ +20 min · 6:55 ] [ +1 cycle · 8:05 ]                        ← tap: logs this sleep, sleeps again
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 [[                      ☀ I'm up                       ]]     ← the only button

opened late   6:35 → "Alarm was at 6:35 AM · 2h ago"; same bar
```

## Just up (S6)

```
 ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
                         6:36 AM
                     Good morning
             7h 13m · 5 cycles · between cycles ✓
                   How do you feel?
      [   😩 Drained   ] [   😐 OK   ] [   😊 Fresh   ]        ← 3 big, one tap, optional (1 / 3 / 5)
 Back to sleep?  [ +20 min · 6:58 ] [ +1 cycle · 8:08 ]
                                                               ← no bar: rating or 2 h ends the state
```

## Morning card (S13) — idle, first hours after the usual wake, no night from the app or Health

```
 Did you sleep last night?
 [[ Yes · 11:00 PM – 7:00 AM ]]  ( Edit… )  ( No )            ← usual hours; Yes → logs, then
                                                                  "How do you feel?"; No → gone for today
```

## States

```
first run    Usually 11:00 PM – 7:00 AM · Set your hours      under the chips; Sleep now works
Health       ( Use 11:12 PM – 6:58 AM from Health )           replaces the line when 14 nights exist
no Health    Nights: "Add nights from Health" button           unchanged
notif off    idle: ⚠ line + Turn on (pre-iOS 26)               moved before the tap
volume low   asleep footnote (pre-iOS 26)                      unchanged
reminder     bar: ( Reminding at 10:35 ✓ )                     tap cancels
alarm past   Ringing layout, "Alarm was at 6:35 AM · 2h ago"
```

## Rejected

```
✗  [ Add nap ]  [[ Set alarm ]]  →  ring replaced by a countdown page  →  [[ I'm in bed now ]]
   Set alarm commits to a mode, not to sleep; the planned state now stays on the same page

✗  No bed handle, alarm only from now
   tried and rejected: can't plan tonight's bed, and the wake moved with the pick each minute

✗  Headline "Bedtime / Asleep by ~11:35 PM · 5 cycles end at 6:35 AM"
   half awake you read one number; the outcome ("Up at 6:35") is the number

✗  ( Cancel )  [[ I'm up ]] while ringing
   both stop the noise; a sleepy thumb drops the night's log

✗  [ Drained ] [ Tired ] [ OK ] [ Good ] [ Fresh ]
   five choices at 6 AM; three big ones get tapped
```

## Components

```
Headline        Up at 6:35 AM                      title1 rounded bold; tap ⌄ unfolds a time wheel (idle)
Fit line        5 cycles · wakes between cycles ✓  subheadline; WakeFit colour
Verdict         Bedtime — asleep by about 11:35.   footnote secondary; red for split night

Wake chip       [ 6:35 AM ] / [[ 6:35 AM ]] / [ 6:45 AM ]!     capsule; picked = indigo; ! = red dot
                caption under: 5 · best / 6 · sleep in / Nap 20
Up-at chip      [ 3:50 ] [ 6:35 ✓ ]                 asleep; ✓ = current alarm; tap = moveAlarm
More chip       [ +1 cycle · 8:05 ]                ringing / just up; tap = sleepMore

Bottom bar      [[ 🌙 Sleep now · up at 6:35 AM ]]  idle, bed = now
                [[ 🛏 Bed at 11:00 PM · up at 6:35 ]] idle, bed later → Waiting
                ( Cancel )  [[ 🌙 Asleep already ]]   waiting
                ( Cancel )  [[ ☀ I'm up ]]          asleep ≤ 15 min
                [[ ☀ I'm up ]]                      asleep > 15 min, ringing

Night mode      black background, text .white.opacity(0.7), tint warm orange, brightness 0.2
Ring            idle: now pin fixed · bed handle (≥ now) · alarm handle with detents at cycle ends from bed
                drag a handle = that end · drag the arc = whole range, same length · elsewhere = nothing
                planned: no drag · counts down to bed
                asleep: no handles · dim · arc fills with elapsed time · cycles in the centre
Rating          3 buttons → energy 1 / 3 / 5 (chart unchanged)
```

## Copy

| Key | String |
|---|---|
| `readout.bed` | BEDTIME · {time} · Now / Today |
| `readout.wake` | WAKE UP · {time} · Tomorrow |
| `button.plan` | Bed at {bed} · up at {wake} |
| `button.inBed` | Asleep already |
| `waiting.bed` | Bed {time} · in {duration} |
| `waiting.alarm` | Alarm {time} is set |
| `waiting.windDown` | Wind down · lights low, screens away |
| `fit.night` | {n} cycles · {WakeFit.text} |
| `fit.nap` | {m}-min nap · {WakeFit.text} |
| `button.sleep` | Sleep now · up at {time} |
| `button.nap` | Nap now · up at {time} |
| `waiting.note` | Asleep from {bed} unless you tap below first; up at {wake}. |
| `toast.cancelled` | Nap cancelled |
| `warn.notifications` | Alarm can't ring — notifications are off |
| `asleep.alarm` | Alarm {time} · in {duration} |
| `asleep.midCycle` | Mid-cycle · sleep on, {time} feels better |
| `asleep.cycleEnd` | Between cycles · OK to get up |
| `asleep.early` | Just dozed off |
| `asleep.off` | Turn off alarm |
| `ringing.title` | Get up |
| `ringing.late` | Alarm was at {time} · {ago} ago |
| `woke.title` | Good morning / Good afternoon |
| `woke.feel` | How do you feel? |
| `woke.more` | Back to sleep? |
| `morning.title` | Did you sleep last night? |
| `morning.yes` | Yes · {bed} – {wake} |

## Deviations from the `uiux` skill

- Asleep / ringing / just up ignore the app's light theme (forced black) — they're read in the
  dark; the rest of the page keeps the theme.
