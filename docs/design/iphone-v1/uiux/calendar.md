# Lunar + How long since

Lunar = third tab. How long since… = pushed from More. "On this day" dropped from v1.

## How long since…
```
‹ More            How long since…               +
─────────────────────────────────────────────────
Quit coffee                            213 days
Feb 24, 2026                    7 mo 1 d        ← swipe left → Delete!
Moved to SF                           3 years
Sep 1, 2023                     3 y 0 mo 24 d
```
```
empty   No events yet — tap + to track one
```
New-event sheet: Name field · DatePicker (date) · ( Cancel ) [[ Add ]]

## Lunar calendar
```
Lunar calendar
─────────────────────────────────────────────────
TODAY
Sep 25, 2026   =   农历 八月 十五  (Lunar 8/15)
─────────────────────────────────────────────────
CONVERT
Date                                Sep 25, 2026
Lunar                               丙午年 八月十五
─────────────────────────────────────────────────
EVENTS
Mom's birthday                      in 205 days
Lunar 3/12 · Yearly                 Apr 18, 2027
Mid-Autumn                          Today 🎉
Lunar 8/15 · Yearly                 Sep 25, 2026
Rent (lunar)                        in 14 days
Lunar 8/29 · Monthly                Oct 9, 2026
Dad's surgery                       Past             ← .never, date gone
Lunar 8/1 · Once                    Sep 11, 2026     ← swipe left → Delete
─────────────────────────────────────────────────
[[              + Add event                    ]]  ← pinned, above tab bar
```
```
empty   EVENTS · No events yet
```

## Add event sheet (large detent)
```
( Cancel )           New event              [[ Add ]]   ← Add disabled until name
─────────────────────────────────────────────────
Name▌                                               ← autofocus
LUNAR DATE
      二月  2    │   十一  11
    ▸ 三月  3    │ ▸ 十二  12                           ← two wheels
      四月  4    │   十三  13
Next                                Apr 18, 2027
─────────────────────────────────────────────────
Repeat                         Every year ⌃⌄        ← Never / Every month / Every year
Add to iPhone Calendar                    ( o)      ← default off
```
- Next occurrence: yearly → same lunar month/day; monthly → next month with day (clamped to 29/30); never → once, anchored at creation.
- Calendar on → write-only EventKit access → all-day events "Mom's birthday (农历 三月十二)" in default calendar; yearly next 10, monthly next 24, never 1 (EKRecurrenceRule can't do lunar). IDs stored on the event.
- Access denied → event still saved; alert: "Calendar access is off — Settings → Privacy & Security → Calendars → Every Time".
- Deleting in-app doesn't remove Calendar events (write-only access can't).
