# Every Time — iPhone v1 UI/UX

Product reasoning: [DESIGN.md](DESIGN.md). Per-screen mocks: [uiux/](uiux/).

## Screen map

```
TabView ─┬─ World ───── + ──▶ [City picker sheet]
         ├─ Sleep
         ├─ Lunar ───── + ──▶ New lunar date sheet
         └─ More (own flat list, not the iOS auto-More)
              TIMERS     ├─▶ Stopwatch
                         ├─▶ Interview
                         ├─▶ Reversal
                         └─▶ LeetCode (timer + history)
              DATES      ├─▶ How long since… ── + ──▶ New event sheet
                         └─▶ Wait times (sample data)
              DEVELOPER  ├─▶ Unix timestamp
                         ├─▶ Timestamp converter
                         └─▶ Cron parser
              (last)     └─▶ Settings ── Export/Import ──▶ [file sheets]
```

## Screens & surfaces

| Screen | Surface | File |
|---|---|---|
| World | tab page | [uiux/world.md](uiux/world.md) |
| City picker | sheet | [uiux/clocks.md](uiux/clocks.md) → City picker |
| More | tab page, flat list → pushed pages | [uiux/more.md](uiux/more.md) |
| 4 timers | pushed from More | [uiux/timers.md](uiux/timers.md) |
| Sleep | tab page | [uiux/sleep.md](uiux/sleep.md) |
| Lunar + How long since | tab page / pushed from More | [uiux/calendar.md](uiux/calendar.md) |
| Dev tools | pushed from More | [uiux/tools.md](uiux/tools.md) |
| Settings (backups) | pushed from More | [uiux/settings.md](uiux/settings.md) |

## Shared components

```
Big time readout        12:34.56          ← monospaced digits, light weight
Timer controls          ( Reset )   [[ Start ]]      idle
                        ( Lap )     [[ Pause ]]!     running (tinted orange)
City row                London                 5:41 PM
                        Today, +8h         ← relative to device tz
Copy row                1758790000         📋  ← tap → copy, toast "Copied"
```

## Deviations from the `uiux` skill

- Restore replaces the backed-up UserDefaults keys instead of creating a new dataset (no database); the before-import zip in Files is the undo. See `EveryTime/Backup/README.md`.
