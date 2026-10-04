# What did I do?

One continuous timeline split by pins; tap a tag to name the range since the last pin. Tab page, `WhatDidView`.

```
 💻 Work since 9:05 AM                           1:37:12   ← open range, live
            ╭──────────── 12 AM ────────────╮
            │  ▒▒ sleep ▒▒                   │               ← today on a clock face, midnight on
     9 PM   │ ▓ eat        Now              │   3 AM          top; arc per range in its colour, tick
            │       💻 Work                 │                 where it started, icon when wide enough;
     6 PM   │      since 9:05 · 1h 37m      │   6 AM          red tick = now; hours ahead blank
            │  ░ untagged ░  ▓ commute      │
            │   ╶── no coffee ──╴ ☕̸        │               ← red band inside the track: 8 h
            ╰──────────── 12 PM ────────────╯                 before the usual bed → bed
         ‹            Today             ›·                   ← step back a day (Yesterday, Thu Oct 2…)
 Tap a tag: it starts at 10:42 AM                            ← one tap = starts now; Sleep, Eat and
                                                                 Wash up ask Start / End
 [ 🍴 Eat ] [ ☕ Coffee ] [ 💻 Work ] [ 📖 Study ]  …          ← tag grid; no Sleep tile: sleeps come from
 … [ 📱 Phone ] [ 🚿 Wash up ] [ ⛪ Church ] [ + New ]            the Sleep page and aren't editable here
                                                                 (a sleep under 3 h shows as 🌙 Nap)
```

```
tap or drag on the track ↓
            │   10:15 AM   ●                 │               ← cursor: blue tick + knob; centre
            │   💻 Work                      │                 shows what was going on then
            │   since 9:05 · 1h 10m         │
 Tap a tag: it starts at 10:15 AM                            ← pins land at the cursor

tap ahead of now ↓
            │    3:00 PM   ●   ╌╌ Work ╌╌    │               ← plan: dashed faint arc in the blank part,
            │   Tap a tag to plan            │                 its icon and tick in the tag's colour
 Tap a tag to plan it for 3:00 PM                            ← one tap, no Start/End

tap empty space ↓     cursor back on Now (tags, buttons and the track keep their own taps)
long-press a tick ↓   Pin at 9:05 AM   ( Edit ) ( Delete )!  ← confirmation dialog
‹ tap ↓               Yesterday                              ← whole day, midnight to midnight; › back
History tap ↓         window jumps to that day, cursor on the range
```

The last pin runs until the next one, but for 12 h at most; after that the "since" line goes
quiet and End isn't offered for it.

A tag tap starts it at the cursor. Sleep, Eat and Wash up ask Start / End (named after the
fact as often as before); any other tile offers "Ended now" in its long-press menu.

**Moments** — Coffee — is a point, not a stretch: one tap pins them (no
Start/End), they draw as a dot with the icon on top of whatever was going on, list in History
without a duration, and never count in totals.


## Activities

```
ACTIVITIES
 3:00 PM   💻 Work   planned                    🔔          ← plans first (today or later, date shown
 6:30 PM   🏃 Workout every day                 🔕             if not today); bell = notification at
                                                               that time; long-press: Edit / Delete.
                                                               "every day" = Repeat in Edit pin: shows
                                                               up at that time for 14 days ahead and
                                                               becomes a real pin as each day comes
 9:05 AM   💻 Work                              now         ← today: every range, newest first
 8:10 AM   🍴 Eat                             55m
 11:20 PM  🛏 Sleep                       7h 50m
 Thu, Oct 2   🛏 7h 40m  💻 6h 10m  🍴 1h 20m   14  ›       ← earlier days: one row each — date, top
 Wed, Oct 1   🛏 8h      💻 5h 30m  🚗 1h       11  ›          three activities, pin count; tap ⌄ to open
tap Thu ↓
 Thu, Oct 2   🛏 7h 40m  💻 6h 10m  🍴 1h 20m   14  ⌄
   10:30 PM  🛏 Sleep                      7h 40m            ← that day's ranges; tap one → ring jumps there
   …
```

## Edit pin (sheet)

```
Cancel            Edit pin               Save
 Planned for                   Sat, Oct 4 · 3:00 PM ›
 Repeat every day                                ─●     ← daily schedule; footer says until when
 Alarm                                           ○─     ← plans and daily pins only
 ACTIVITY   [ Eat ] [ Coffee ] [[ Work ]] …
 Remove pin                                             ← red; confirm; a daily pin's occurrences go with it
```

## New activity (sheet; also "Icon and colour…" in a custom tile's menu)

```
Cancel          New activity            Add·   ← Add enabled once the name is new
╭──────────────────────────────────────╮
│ [🏷]  Name                           │        ← preview tile in the picked colour; name fixed after creation
╰──────────────────────────────────────╯
COLOUR
 ● ● ● ● ● ● ●                                  ← 13 named colours, ✓ on the pick
 ● ● ● ● ● ●
ICON
 🏷 ★ ♥ ⚑ 📖 ✎ 🎓                                ← ~50 SF symbols in a 7-wide grid
 ♪ 🎧 📺 🎬 🎮 📷 🖌  …
```
