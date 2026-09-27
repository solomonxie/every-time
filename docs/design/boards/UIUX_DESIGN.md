# Boards — UI/UX

Product: [DESIGN.md](DESIGN.md). Visual language: `docs/design/iphone-v1/uiux/visual.md` (Card, SectionLabel, bottom bar).

## Screen map

```
More ─▶ Boards list ──tap──▶ Board ─[ Board | Roadmap | Insights ]
          │  ⊕                 │ tap card ──▶ Card sheet
          ▼                    │ ⊕ ─────────▶ Card sheet (new)
      New board sheet          │ ⋯ ─────────▶ Board settings sheet
                               └ long-press card ▶ Move to ▸ menu
  permission denied ─▶ [Settings app]
```

| Surface | Kind | Why |
|---|---|---|
| Boards list | page (More → Projects → Boards) | entry, one row per board |
| Board | page, 3-way segmented | the work itself |
| Card | sheet (large) | edit without losing board context |
| New board | sheet (medium) | pick a list or name a new one |
| Board settings | sheet (large) | columns, WIP, milestone calendar |
| Move to | context menu | drag alternative, one-handed |

## Boards list

```
‹ More              Boards
╭────────────────────────────────────────╮
│ ● Shelf project                  (12) ›│  ← list colour dot · open cards
│   ██████░░░░ 60% · 3 in progress       │  ← done / (open + done 90d)
├────────────────────────────────────────┤
│ ● Every Time v2                  (31) ›│
│   ██░░░░░░░░ 18% · 1 overdue           │  ← overdue replaces in-progress when > 0
╰────────────────────────────────────────╯
[[            ⊕ New board             ]]    ← bottom bar
```

States:
```
first run   ☐ Boards live in Reminders           ← no access asked yet
            Each board is a Reminders list; cards are reminders.
            [[ Allow Reminders ]]
denied      ⚠ Reminders access is off
            ( Open Settings )
empty       No boards yet — turn a Reminders list into one   [[ ⊕ New board ]]
loading     ⟳
```

Swipe row → `Remove board` (config only; list and reminders stay — footer says so).

## New board sheet

```
( Cancel )         New board
USE A REMINDERS LIST
(•) Groceries                      8 items
( ) Shelf project                 14 items
( ) Work                           3 items
OR CREATE ONE
┌──────────────────────────────────────┐
│ New list name                        │
└──────────────────────────────────────┘
COLUMNS
[ Backlog · In progress · Review · Done ]   ← template, editable later
[[                Create                ]]·  ← disabled until a list is chosen/named
```

Lists already used as boards are hidden. Templates: `Simple` (To do · Doing · Done), `ZenHub` (New · Icebox · Backlog · In progress · Review · Done).

## Board — Board view

Columns page horizontally, one ~88 % wide so the next peeks.

```
‹ Boards        Shelf project           ⋯
[ BOARD | Roadmap | Insights ]
BACKLOG  4            IN PROGRESS  3/3 ⚠  │ RE…   ← count / WIP limit, ⚠ at limit
╭────────────────────────╮ ╭──────────────│
│ Buy parts for the shelf│ │ Cut planks   │
│ ⏰ Oct 2 · 3 pts       │ │ ⏰ Today !    │   ← overdue/today in tint/red
╰────────────────────────╯ ╰──────────────│
╭────────────────────────╮ ╭──────────────│
│ Find wall anchors      │ │ Sand edges…  │   ← 2-line clamp
│ 1 pt                   │ │ 5 pts · 📝   │   ← 📝 = has notes
╰────────────────────────╯ ╰──────────────│
  ⊕ Add card                                    ← per column, appends here
• ○ ○ ○                                         ← page dots = columns
```

- Drag a card onto another column (or hold at the edge to page) → moves; Done completes the reminder.
- Long-press card → menu:
```
┌──────────────────────┐
│ Move to            ▸ │ → Backlog ✓ · In progress · Review · Done
│ Open in Reminders    │   ← x-apple-reminderkit://REMCDReminder/<id>
├──────────────────────┤
│ Delete…            ! │   ← confirm alert
└──────────────────────┘
```
- Done column: completed in the last 90 days, newest first, strikethrough-free, secondary text.

States:
```
empty column   Nothing here                      (dim, no card)
empty board    No cards yet  [[ ⊕ Add card ]]
list deleted   ⚠ This Reminders list is gone   [ Remove board ]
```

## Board — Roadmap view

Weeks across, cards with due dates as bars at their day; calendar milestones as flags.

```
[ Board | ROADMAP | Insights ]
        Sep 28   Oct 5   Oct 12   Oct 19
        │ today  │       │        │
◆ v1 release ────────────◆ Oct 14          ← milestone (calendar event), all rows
Buy parts        ●                          ← dot = due, colour = column
Cut planks    ●!                            ← ! overdue
Sand edges              ●
No date: 3 cards ›                          ← opens filtered list
```

Rows sorted by due date; tap row → Card sheet. Milestones need a calendar chosen in Board settings; else footer `Pick a calendar in ⋯ to show milestones`.

## Board — Insights view

```
[ Board | Roadmap | INSIGHTS ]
╭ Progress ────────────────────────────╮
│ 12 done · 9 open · 57%               │
│ █████████████████░░░░░░░░░░░░         │
│ 2 overdue · 3 due this week          │
╰──────────────────────────────────────╯
╭ Burn-up · 8 weeks ───────────────────╮
│ 20┤            ╱‾‾‾ total            │   ← created (cumulative)
│   │      ╱‾‾‾‾╱   ___ done           │   ← completed (cumulative)
│  0┼────────────────────              │
╰──────────────────────────────────────╯
╭ Velocity · per week ─────────────────╮
│ ▂ ▅ ▃ ▇ ▅ ▆ ▂ ▄    avg 4.2 cards     │   ← points if any card has points
╰──────────────────────────────────────╯
╭ Flow · since Sep 3 ──────────────────╮
│ stacked area per column, daily       │   ← from local snapshots
╰──────────────────────────────────────╯
╭ By column ───────────────────────────╮
│ Backlog      ████████   8            │
│ In progress  ███        3            │
╰──────────────────────────────────────╯
```
Flow shows `Builds up from today — check back in a few days` until 2+ snapshots.

## Card sheet

```
( Cancel )        Card               ( Save )
┌──────────────────────────────────────┐
│ Buy parts for the shelf▌             │   ← autofocus on new card
└──────────────────────────────────────┘
Column               [ In progress ⌄ ]      ← menu picker
Estimate             [−]  3 pts  [+]        ← 0 = none
Due                                ─●  Oct 2 ⌄
Priority             [ None | ! | !! | !!! ]
NOTES
┌──────────────────────────────────────┐
│ Bosch 6 mm anchors                   │   ← trailer line hidden here
└──────────────────────────────────────┘
Open in Reminders                      ›
Delete card…                           !
```

## Board settings sheet

```
( Done )        Board settings
COLUMNS                            ← drag ≡ to reorder, swipe to delete
≡ Backlog                    WIP –
≡ In progress                WIP 3   [−][+]
≡ Review                     WIP –
  Done                       (always last, completes the reminder)
⊕ Add column
MILESTONES
Calendar                  [ Work ⌄ ]   ← None / any writable calendar
⊕ Add milestone…                       ← title + date → calendar event
```

Renaming a column rewrites the trailer on its cards (confirm: `Rename on 8 cards?`). Deleting a column moves its cards to the first column.

## Copy

| Key | String |
|---|---|
| tool title | Boards |
| access body | Each board is a Reminders list; cards are reminders. Nothing leaves your iPhone. |
| remove footer | Removes the board here. The Reminders list and its reminders stay. |
| delete alert | Delete “%@”? It's removed from Reminders on all your devices. |

## Deviations from the `uiux` skill

None.
