# Timers

Four timers, listed in the More tab ([more.md](more.md)); each pushes its own page.

```
Timers
─────────────────────────────────────────────────
⏱ Stopwatch                                    ›
🎤 Interview                          45:00    ›
↺ Reversal                            10:00    ›
</> LeetCode                  12 sessions      ›
```

Timers keep correct time across backgrounding (start date stored, not ticks).

Every timer page has a toolbar button `⤡` (Full screen, top-right, always enabled) → Big clock.

## Stopwatch
```
‹ Timers            Stopwatch            ⤡
            01:23.45
      ( Reset )        [[ Start ]]      ← idle/paused: Reset + Start
      ( Lap )          [[ Stop ]]!      ← running: Lap + Stop
─────────────────────────────────────────────────
Lap 3                                   00:21.07
Lap 2                                   00:30.11   ← fastest green, slowest red
Lap 1                                   00:32.27
```

## Interview (countdown)
```
‹ Timers            Interview            ⤡
             44:12
      [████████████████░░░░░░░] 98%
      ( Reset )        [[ Pause ]]
Duration                   [−]  45 min  [+]     ← 5-min steps, disabled while running
```
```
done   00:00 red, "Time's up", haptic
```

## Reversal (countdown then overtime)
```
‹ Timers            Reversal             ⤡
             03:12                      ← counting down
      ( Reset )        [[ Pause ]]
Duration                   [−]  10 min  [+]
```
```
overtime   +02:41  (orange)   "Overtime"    ← flips to count-up at zero, keeps going
```

## LeetCode
```
‹ Timers            LeetCode             ⤡
┌───────────────────────────────────────────────┐
│ Problem  ┌──────────────────────────────┐     │
│          │ 1. Two Sum                   │     │
│          └──────────────────────────────┘     │
│ Difficulty   [ Easy | MEDIUM | Hard ]         │
│                 18:04                         │
│      ( Reset )        [[ Start ]]             │
│                        [ Finish & Save ]      │ ← enabled once time > 0
└───────────────────────────────────────────────┘
HISTORY                                 12 · avg 21:40
1. Two Sum          Medium    18:04   Sep 25
146. LRU Cache      Hard      41:12   Sep 24    ← swipe left → Delete!
```
```
empty history   No sessions yet — finish one to save it here
```

## Big clock (full screen, sideways)
App stays portrait-locked; the cover's content is rotated 90° so it reads with the phone turned
left (top of phone to the left). Shown as seen when held sideways:
```
┌──────────────────────────────────────────────────────────────┐
│                         1. Two Sum                           │ ← LeetCode only: problem name
│                                                              │
│      ██  ███ █  █ ███   ███  ██                              │
│      44 : 12         ← digits scaled to fill, black bg       │
│                        Time's up / Overtime (when relevant)  │
│                                                              │
│  (✕)                              ( Reset )   [[ Start ]]    │ ← dimmed; same controls as page
└──────────────────────────────────────────────────────────────┘
  portrait bottom (home indicator) is on the right edge
```
- Same live value + colors as the page: stopwatch hundredths; Interview red `00:00` at zero; Reversal orange `+mm:ss`.
- Controls: Start/Pause(Stop), Reset or Lap (stopwatch, running), ✕ closes.
- Screen stays awake while shown; status bar + home indicator hidden.
