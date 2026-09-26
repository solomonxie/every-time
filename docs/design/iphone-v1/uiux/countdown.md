# Countdown

Count down to any future date/time; the largest non-zero unit is the hero.
Timers group in More ([more.md](more.md)). Visual language: [visual.md](visual.md).
Code: `EveryTime/Features/Countdown/`. Stored: `timers.countdowns` (backed up).

## List
```
‹ More              Countdown
╭───────────────────────────────────╮
│ Launch                   32 min   │   ← focus value Font.clock 40 + unit
│ Sat, Sep 26, 2026 10:00 PM   10s  │   ← lower units, small
╰───────────────────────────────────╯
╭───────────────────────────────────╮
│ New Year                 97 days  │
│ Fri, Jan 1, 2027 12:00 AM 01:44:50│
╰───────────────────────────────────╯
DONE  1
╭───────────────────────────────────╮
│ Standup                        ✓  │   ← dimmed
│ Finished Sep 26, 9:00 AM          │
╰───────────────────────────────────╯
[[           + New countdown          ]]
```
- Soonest first; finished under Done (latest first). Swipe to delete. Tap → detail. Ticks every second.
- Empty: `No countdowns` · hourglass · "Count down to a date and time — with fireworks, sound and a notification when it arrives."

## New / edit (sheet)
```
Cancel          New countdown
╭───────────────────────────────────╮
│ e.g. New Year                     │   ← autofocus
╰───────────────────────────────────╯
╭───────────────────────────────────╮
│ Ends          Sep 26, 2026  11:00 PM   ← future only for new
│ (+10 min) (+1 hour) (Tomorrow 9 AM) (New Year's Eve midnight) →
╰───────────────────────────────────╯
WHEN TIME'S UP
│ ✦ Animation                   (●) │
│   [ Fireworks | Confetti ]        │   ← only when Animation on
│ 🔊 Sound                      (●) │
│ 📳 Vibrate                    (●) │
│ 🔔 Notification               (●) │
Animation, sound and vibration play while the countdown is open.
A notification alerts you even when the app is closed.
[[               Save                 ]]
```
- All options on by default, Fireworks. Save disabled without a name (or past target for new).
- Picker edits snap to whole minutes; presets keep exact time.

## Detail — focus rules
Upper units hidden when zero. Focus value ~120pt thin, lower units ~40pt, unit label small caps.
```
≥ 1 day              < 1 day             < 1 hour           < 1 minute
      Launch               Launch              Launch             Launch
 Sat, Sep 26 10 PM    Sat, Sep 26 10 PM   Sat, Sep 26 10 PM  Sat, Sep 26 10 PM

   12 DAYS              5 H                 32 MIN              42 SEC
   05:32:10             32:10               10s

 ━━━━━━━━━──────      ━━━━━━━━━━━━──      ━━━━━━━━━━━━━─     ━━━━━━━━━━━━━━  ← createdAt → target
   ( ✎ Edit )           ( ✎ Edit )          ( ✎ Edit )         ( ✎ Edit )
```
- One toolbar item: `⤡` Full screen.
- Finished: `✓` · "Time's up" · "Finished Sep 26, 10:00 PM" · ( Edit ) ( ▶ Replay ).

## Sideways (full screen)
```
╭─────────────────────────────────────────────────────╮
│ ⊗  Launch                             Sep 26, 10 PM │
│                                                     │
│              32  MIN                                │  ← scaled to fill
│                 10s                                 │
╰─────────────────────────────────────────────────────╯
```
Black, rotated 90° (`SidewaysScreen`), screen kept awake.

## Time's up
```
╭───────────────────────────────────╮
│   *  .  ✺        .   *     ✺      │  ← fireworks bursts / confetti rain, ~6s
│        Time's up!                 │
│          Launch                   │
│  ✺     .    *      ✺    .   *     │     tap to dismiss
╰───────────────────────────────────╯
```
- Fires once per countdown per app run, when it hits 0 while the detail or sideways view is open; reopening a finished one doesn't re-fire — Replay does.
- Animation → overlay; Vibrate → 4 vibrations; Sound → system alarm sound ×3.
- Notification → scheduled at the target (sound only if Sound is on), ids `countdown.*`, 10 soonest max within iOS's 64-pending cap; rescheduled on add/edit/delete and app active.
