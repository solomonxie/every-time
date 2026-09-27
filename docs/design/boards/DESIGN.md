# Boards — design

UI: [UIUX_DESIGN.md](UIUX_DESIGN.md) · Build: [IMPLEMENT_PLAN.md](IMPLEMENT_PLAN.md)

## Problem

ZenHub / GitHub Projects give a board, a roadmap and burn charts — but only
for issues on a server, with an account. Personal projects already live in
Reminders and Calendar, which have lists and dates but no board, no columns,
no progress view.

## Goals

- ZenHub-style project boards on iPhone, stored only in Reminders / Calendar.
- Board = a Reminders list; card = a reminder; Done = completed.
- Views: Board (kanban), Roadmap (due dates + milestones), Insights (burn-up, velocity, flow).
- Every write is a normal reminder edit — Reminders on Mac/iPad/Watch keeps working and syncs via iCloud as usual.
- Zero network, zero account.

## Non-goals

- GitHub / ZenHub import or sync.
- Assignees, comments, labels (Reminders tags and subtasks aren't in EventKit).
- Cumulative flow by column from before the app saw the board (EventKit keeps no history).
- iPad layout, sharing boards.

## Options considered

- Card column: Reminders sections / tags → **not in EventKit**. URL field → overwrites links users keep there. Priority → only 4 values, already meaningful. **Notes trailer line** → readable and editable in Reminders, one line.
- Board config (columns, order): in Reminders → no free field on a list. **App storage `boards.*`** → backed up with everything else; losing it only resets column names, never cards.
- Milestones: extra reminders → pollute the list. **Calendar events** in a chosen calendar → native, dated, already how people mark deadlines.
- Flow history: none → no cumulative flow. **Local daily snapshot of column counts** → CFD grows from first use; cheap.

## Decision

Reminders list = board, reminder = card, `isCompleted` = Done. Column and
estimate travel in one trailer line at the end of notes:

```
Buy parts for the shelf
…user notes…
— Board: In progress · 3 pts
```

- Missing / unknown column → first column. Completed → Done regardless of trailer.
- The app rewrites only that line; user notes above are never touched.
- Board config (`boards.config`): list id → columns, milestone calendar id, WIP limits. Snapshots (`boards.flow`): per board per day, count per column.

## Data & integrations

- EventKit full access to Reminders (new `NSRemindersFullAccessUsageDescription`) and Events (already asked by Important events).
- Reads: reminders in board lists (incomplete + completed last 90 days), events in the milestone calendar ±1 year.
- Writes: create / edit / complete / delete reminders; create lists; create milestone events.
- `EKEventStoreChanged` → reload, so edits made in Reminders show up live.

## Risks / open questions

- Users editing the trailer by hand → parser is lenient (case, spacing, missing points); unknown column → first column.
- Large lists (1000+ reminders) → fetch completed within 90 days only.
- Deleting a card deletes the reminder everywhere → always confirmed; default action is "Move to Done".
- Reminders' own Sections feature is invisible to EventKit; a list organised by sections in Reminders shows flat here.
