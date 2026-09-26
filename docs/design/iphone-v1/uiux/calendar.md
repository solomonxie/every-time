# Lunar + Important events

Lunar = third tab. Important events (tab label "Events") = pushed from More, pinnable. "On this day" dropped from v1.

## Important events
Stored in `calendar.since` (old name/date items decode as type Other, manual, notify on). Logic: `EveryTime/Features/Events/Anniversary.swift`.
```
‹ More
Important events
TODAY
╭─────────────────────────────────────────╮   ← accent-tinted card, only on the day
│ 🎉 5th wedding anniversary — Alex & Sam │
│ Since Sep 25, 2021                      │
╰─────────────────────────────────────────╯
UPCOMING                                       ← next anniversaries ≤ 30 days
╭─────────────────────────────────────────╮
│ 🎂 Mom                       in 12 days │
│    Turns 64                             │
╰─────────────────────────────────────────╯
ALL EVENTS  3
╭─────────────────────────────────────────╮
│ ⚑ Moved to SF         3 years 24 days │   ← type icon (tinted) · Font.clock, one line (scales down)
│   Sep 1, 2023              1,120 days │   ← total days; "to go ·" prefix if future
│ 4 years since Moved to SF · Sep 1, 2027 │   ← next anniversary phrase
│ · in 341 days                           │
╰─────────────────────────────────────────╯   ← tap → edit · swipe left → Delete
[[              + Add event                ]]
```
Since hero: ≥ 1 year → `N years N days` · ≥ 1 month → `N months N days` · else `N days` (no caption).
```
empty   ☆  No important events
        Birthdays, anniversaries, milestones — see how long it's been
        and get a note every year.
```
Phrasing (next / on the day):
| Type | Upcoming | Today |
|---|---|---|
| Birthday | Turns 34 | 34th birthday 🎂 |
| Anniversary · Relationship | 5th anniversary | 5th anniversary |
| Wedding | 5th anniversary | 5th wedding anniversary |
| Memorial | 5 years since | 5 years since (🕯 instead of 🎉) |
| Milestone · Other | 5 years since <name> | same |

Feb 29 → Feb 28 in non-leap years. Future dates count "N days to go".

## Add choice
```
[[ + Add event ]] →  ┌ Add event ──────────┐
                     │ From Calendar…      │
                     │ Enter manually      │
                     │ Cancel              │
                     └─────────────────────┘
```

## From Calendar
```
( Cancel )          From Calendar
╭ 🔍 wedding▌                        ⓧ ╮     ← autofocus
╭─────────────────────────────────────────╮
│ ● Wedding                             › │   ← ● calendar color
│   Sep 25, 2021 · Home                   │
╰─────────────────────────────────────────╯
╭─────────────────────────────────────────╮
│ ● Sam's wedding anniversary           › │   ← recurring → earliest occurrence
│   Jun 2, 2019 · Family                  │
╰─────────────────────────────────────────╯
```
- Full access (`requestFullAccessToEvents`); events from 30 years back to 2 ahead, loaded once in ≤4-year chunks off the main thread, deduped by `calendarItemIdentifier` (earliest wins); title filter, max 100.
- Empty query: "Search N events from the past 30 years"; no hits: "No matching events".
- Pick → pushed editor, prefilled; type guess: Birthdays calendar or "birthday"/"生日" → Birthday, "anniversary"/"纪念" → Anniversary, else Other.
```
denied   📅  Calendar access is off
             Settings → Privacy & Security → Calendars → Every Time
             ( Open Settings )
```

## Edit sheet
```
( Cancel )            New event                  ← "Edit event" when editing; ‹ back when from Calendar
╭ Alex & Sam▌ ──────────────────────────╮        ← autofocus when empty
📅 From Calendar: Wedding                        ← only for calendar picks
╭───────────────────────────────────────╮
│ Date                     Sep 25, 2021 │
│ Type                     ♡ Wedding  ⌄ │        ← Birthday · Anniversary · Wedding · Relationship · Memorial · Milestone · Other
╰───────────────────────────────────────╯
╭───────────────────────────────────────╮
│ 🔔 Remind me yearly              (o ) │        ← default on
╰───────────────────────────────────────╯
A notification at 9:00 AM on each anniversary.
[[                Add / Save             ]]      ← disabled until name
```
- Notifications: one non-repeating local notification per event at 9:00 on the next anniversary (text carries the ordinal, so rescheduled yearly), ids `important.<uuid>`; soonest 20, never past the free share of iOS's 64 pending (jet lag uses the rest). Rescheduled on add/edit/delete and when the app becomes active. Permission asked only on saving an event with the reminder on.

## Lunar calendar
```
Lunar
╭─────────────────────────────────────────╮
│ Today                                   │
│ 八月十五                                 │   ← large rounded
│ 丙午年               Fri, Sep 25, 2026  │
│                             Lunar 8/15  │
╰─────────────────────────────────────────╯
╭─────────────────────────────────────────╮
│ CONVERT                                 │
│ ( Sep 25, 2026 )  →          八月十五    │   ← date pill → lunar
│                    丙午年 · Lunar 8/15   │
╰─────────────────────────────────────────╯
EVENTS  3
╭─────────────────────────────────────────╮
│ Mom's birthday                 205 days │   ← Font.clock count
│ Lunar 3/12 · Yearly                     │
│ Apr 18, 2027                            │
╰─────────────────────────────────────────╯
╭─────────────────────────────────────────╮
│ Mid-Autumn                   Today 🎉   │   ← accent
│ Lunar 8/15 · Yearly                     │
╰─────────────────────────────────────────╯
╭─────────────────────────────────────────╮
│ Dad's surgery                     PAST  │   ← .never, date gone; swipe → Delete
│ Lunar 8/1 · Once                        │
╰─────────────────────────────────────────╯
[[              + Add event                ]]  ← bottom primary, above tab bar
```
```
empty   EVENTS · 📅 No events yet — add a birthday or festival
```

## Add event sheet (large detent)
```
( Cancel )           New event
─────────────────────────────────────────────────
╭ e.g. Mom's birthday▌ ─────────────────╮        ← autofocus
LUNAR DATE
╭───────────────────────────────────────╮
│     二月  2    │   十一  11            │
│   ▸ 三月  3    │ ▸ 十二  12            │        ← two wheels
│     四月  4    │   十三  13            │
│ Next                      Apr 18, 2027│
╰───────────────────────────────────────╯
REPEAT
( Once | Monthly | [Yearly] )                     ← segmented
╭───────────────────────────────────────╮
│ 📅 Add to iPhone Calendar        ( o) │        ← default off
╰───────────────────────────────────────╯
Adds all-day events to your default calendar.
[[                  Add                  ]]      ← bottom, disabled until name
```
- Next occurrence: yearly → same lunar month/day; monthly → next month with day (clamped to 29/30); never → once, anchored at creation.
- Calendar on → write-only EventKit access → all-day events "Mom's birthday (农历 三月十二)" in default calendar; yearly next 10, monthly next 24, never 1 (EKRecurrenceRule can't do lunar). IDs stored on the event.
- Access denied → event still saved; alert: "Calendar access is off — Settings → Privacy & Security → Calendars → Every Time".
- Deleting in-app doesn't remove Calendar events (write-only access can't).

### Countdown (future events)

Any event dated in the future (manual or from Calendar) is a countdown; once it passes it moves to **Since** and gets anniversaries.
```
COUNTDOWN
╭───────────────────────────────────────────────╮
│ ✈  Trip to Tokyo                6 weeks to go │   ← accent
│    Sat, Nov 7, 2026            6 wk 3 d · 45 days │
╰───────────────────────────────────────────────╯
SINCE  4
…existing cards…
```
| Time left | Shown as | Detail |
|---|---|---|
| < 1 h (timed) | 40 minutes | at 3:40 PM |
| < 48 h (timed) | 5 hours | 5h 12m |
| < 14 days | 9 days | Monday / tomorrow |
| < 3 months | 6 weeks | 6 wk 3 d · 45 days |
| < 2 years | 6 months | 6 mo 19 d · 200 days |
| ≥ 2 years | 3 years | 3 y 0 mo · 1100 days |

Editor: **Time** toggle adds hour/minute (Calendar picks keep their time unless all-day). Reminder fires when it arrives (its time, or 9:00 AM all-day), then yearly. Updates every 30 s.
