# World

First tab (globe). Replaces the old Clocks list + Meetings tab. World Time Buddy–style planner. Pinned city column, hour strips sharing one
horizontal scroll (−1 … +7 days), fixed center cursor = the instant being compared. Visual language: [visual.md](visual.md).

```
World                                                ← large title
9:45 PM                                              ← hero: cursor time (local), Font.clock 56
Friday, Sep 25 · Now                                 ← date · "Now" / "in 3h 15m" (accent when off now)

                              ╭─────╮
                              │10:45│                ← cursor bubble (accent), shows cursor time
🏠 Vancouver             ╭────┴──┬──┴───╮╭───╮╭───── ← rows = rounded strips, 6pt gaps
9:45 PM                  │ 8  9  │ 10 11 ││Sat││ 1  2   same-shade hours merge into one band
                         ╰───────┴──────╯│ 26│╰─────   ░ edge  ▓ night  █ work (Theme.Tone, soft)
London              +8h  ╭──────────────╮╰───╯╭────   midnight = own subtle cell "Sat 26"
5:45 AM  Sat             │ 4  5  │ 6  7 ...           hour digits small/light, am/pm tiny
                         ╰──────────────╯
Singapore          +15h  ╭─────  │  ────────────
12:45 PM  Sat            │ 11 12 │ 1  2 ...        ← thin red line = real now
                                 │               ← thin accent line = cursor
OVERLAP · Fri 25
╭───────────────────────────────────────────────╮
│ ( 8 – 9 AM )  ( 4 – 5 PM )                    │  ← pill chips; tap → cursor jumps; filled = contains cursor
├───────────────────────────────────────────────┤
│ Target hours                   8 AM – 6 PM  › │  ← tap → unfolds in place, › → ⌄
│ ( Work 8 AM – 6 PM )  ( Awake 7 AM – 11 PM )  │  ← presets
│        8 AM   –   6 PM                        │  ← From / To hour wheels
│ In each city's local time                     │
╰───────────────────────────────────────────────╯
 or   ☾ No shared target hours this day
```
- Target hours (`world.targetHours`) drive the chips and the grid bands: work = target,
  edge = 2h before / 4h after, rest night. End before start wraps past midnight; equal = all day.

City label: name (cardTitle, 🏠 for local), time at cursor (Font.clock 22), secondary = weekday if another day · offset.

```
──────────────────────────────────────────────── bottom bar, above tab bar
( ➤ Now )  ( Edit )  [[        + Add City        ]]
   ↑ dimmed/disabled while already following now
```

Edit mode:
```
🏠 Vancouver         ≡ │ …      ← local: movable, not removable
⊖ London             ≡ │ …      ← ⊖ removes; ≡ = drag hint
```

- Drag snaps to 15 min; labels + hero show each city's time at the cursor.
- Now: cursor = exact current time (no snap), keeps following the clock until the user drags.
- Long-press + drag a city label onto another row → reorder (any time, incl. local row).
- Remove: ⊖ in Edit mode, or long-press → Remove.
- 12h/24h follows locale.

## States
```
no cities   Local row only + "Tap + to add a city to compare"
following   hero says "Now", Now button dimmed, cursor ticks with the clock
```

## Full screen (sideways)

Toolbar ⤢ → full-screen cover drawn rotated 90° (`SidewaysScreen`, shared with timers' big clock).
```
( ✕ )                                              NOW   ← or cursor date/time in accent
╭─────────────────────╮ ╭─────────────────────╮
│ 🏠 Vancouver  Fri   │ │ London   Sat · +8h  │   ← tile tinted by HourShade
│   11:50 PM          │ │   7:50 AM           │   ← thin rounded, scales to fit
╰─────────────────────╯ ╰─────────────────────╯
╭─────────────────────╮ ╭─────────────────────╮
│ New York Sat · +3h  │ │ Singapore Sat ·+15h │
│   2:50 AM           │ │   2:50 PM           │
╰─────────────────────╯ ╰─────────────────────╯
```
Columns: 1–2 cities → one row; 3–4 → 2×2; 5+ → 3 columns. Live each second when following now; frozen at the cursor otherwise. Screen stays awake.
