# World

First tab (globe). Replaces the old Clocks list + Meetings tab. World Time Buddy–style planner. Pinned city column, hour strips sharing one
horizontal scroll (−1 … +7 days), fixed center cursor = the instant being compared.

```
World
Friday, Sep 25                              in 3h    ← cursor vs now, 15-min steps
               ▼                                     ← cursor, fixed at strip center
🏠 Vancouver  │ 6  7  8  9 ┃10 11 │Sep│ 1  2        ← ░ edge  ▓ night  █ work
9:45 PM       │ pm pm pm pm┃pm pm │26 │ am am
Fri, Sep 25   │            ┃      │   │            ← grey cell = midnight, shows date
London        │ 2  3  4  5 ┃6  7  8  9 …
5:45 AM       │            ┃
Sat · +8h     │            ┃
Singapore     │ 9 10 11 12 ┃1  2  3  4 …
12:45 PM      │            ┃                        ← red hairline = real now
─────────────────────────────────────────────────
WORK HOURS OVERLAP                                   ← cursor's local day
8 – 9 AM                                     ➜      ← tap → cursor jumps there
 or ⚠ No shared 8 AM – 6 PM window this day
```

```
─────────────────────────────────────────────────   bottom bar, above tab bar
[ ➤ Now ]                      [ Edit ]  [[ + Add City ]]
```

Edit mode:
```
🏠 Vancouver           ≡ │ …      ← local: movable, not removable
London              ⊖  ≡ │ …      ← ⊖ removes; ≡ = drag hint
```

- Scroll snaps to 15 min; left labels show each city's time at the cursor.
- Long-press + drag a city label onto another row → reorder (any time, incl. local row).
- Remove: ⊖ in Edit mode, or long-press → Remove.
- 12h/24h follows locale.

## States
```
no cities   Local row only + "Tap + to add a city to compare"
```
