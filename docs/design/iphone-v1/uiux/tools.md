# Tools

Visual language: [visual.md](visual.md). Every copy shows a brief `✓ Copied` toast at the bottom + success haptic.

```
Tools
─────────────────────────────────────────────────
Unix timestamp                                 ›
Timestamp converter                            ›
Cron expression parser                         ›
```

## Unix timestamp (live)
```

             1758790867                ← Font.clock thin, ticks each second, tap to copy
    Seconds since 1970 · tap to copy

╭───────────────────────────────────╮
│ Seconds                           │
│ 1758790867                     ⧉  │  ← label over value, copy icon
│ Milliseconds                      │
│ 1758790867123                  ⧉  │
│ ISO 8601                          │
│ 2026-09-25T09:41:07Z           ⧉  │
╰───────────────────────────────────╯
               ( ✓ Copied )             ← toast
```

## Timestamp converter
```
TIMESTAMP → DATE
╭───────────────────────────────────╮
│ 1758790867▌               ( Now ) │  ← monospaced; s or ms auto-detected (>1e11 = ms)
│ Read as seconds                   │
╰───────────────────────────────────╯
╭───────────────────────────────────╮
│ Local                             │
│ Thu, Sep 25, 2026, 2:41:07 AM  ⧉  │
│ UTC                               │
│ Thu, Sep 25, 2026, 9:41:07 AM  ⧉  │
│ Relative                          │
│ 5 minutes ago                  ⧉  │
╰───────────────────────────────────╯

DATE → TIMESTAMP
╭───────────────────────────────────╮
│ Date        [Sep 25, 2026  2:41 AM]│
│ Seconds          1758790860    ⧉  │
│ Milliseconds     1758790860000 ⧉  │
╰───────────────────────────────────╯
```
```
invalid   ⚠ Not a number   (orange, inside the input card; results card hidden)
```

## Cron parser
```
╭───────────────────────────────────╮
│ */15 9-17 * * 1-5▌                │  ← monospaced
│ minute  hour  day  month  weekday │  ← hint, or ⚠ error in orange
╰───────────────────────────────────╯
Every 15 minutes, 9–17h, Mon–Fri       ← large readable summary

NEXT RUNS
╭───────────────────────────────────╮
│ Fri, Sep 26                9:00 AM│
│ Fri, Sep 26                9:15 AM│
│ … (5 rows)                        │
╰───────────────────────────────────╯

EXAMPLES
( @hourly ) ( 0 0 * * * ) ( 30 8 * * 1 ) ( */15… →   ← horizontal scroll chips, tap fills field
```
```
invalid   ⚠ Expected 5 fields, got 4   (orange, in the input card; summary + runs hidden)
```
Supports: `* , - /`, numbers, JAN–DEC, SUN–SAT, @hourly/@daily/@weekly/@monthly/@yearly.
