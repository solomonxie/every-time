# Timers

Four timers, listed in the More tab ([more.md](more.md)); each pushes its own page.
Visual language: [visual.md](visual.md).

```
Timers
─────────────────────────────────────────────────
⏱ Stopwatch                                    ›
🎤 Interview                          45:00    ›
🧍 Rehearsal                          10:00    ›
</> LeetCode                  12 sessions      ›
```

Timers keep correct time across backgrounding (start date stored, not ticks).

Shared page anatomy
- Digits are the hero: `Font.clock` ~88pt thin, centered, numeric content transitions.
- Tiny state caption under the digits (Ready · Running · Paused · Ends 10:45 PM · Overtime · Time's up).
- Two large round buttons: soft left (Reset / Lap), tinted right (Start/Resume accent · Pause orange · Stop red).
- Haptics on start/stop, lap, save, duration change; warning haptic at zero.
- One toolbar item: `⤡` Full screen → Big clock.

## Stopwatch
```
‹ More              Stopwatch            ⤡

             01:23.45                   ← thin, hundredths
               Lap 4                    ← caption: Ready / Running / Lap n / Stopped

   ( Reset )                  (● Start ●)   ← idle/stopped
   (  Lap  )                  (● Stop  ●)   ← running (red)

Lap 3                               00:21.07
Lap 2                               00:30.11  ← fastest green, slowest red
Lap 1                               00:32.27
```

## Interview (countdown)
```
‹ More              Interview            ⤡
            ╭─────────────╮
          ╭╯               ╰╮
         │      44:12        │         ← thin ring = time left (accent)
         │   Ends 10:45 PM   │
          ╰╮               ╭╯
            ╰─────────────╯
            ( −  45 min  + )            ← pill stepper, 5-min steps, disabled while running

   ( Reset )                  (● Pause ●)
```
```
done   ring full red · 00:00 red · "Time's up" · warning haptic · stops
```

## Rehearsal (countdown, then overtime)
Timing a talk slot: counts down, then keeps going as overtime.
```
‹ More              Rehearsal            ⤡
         ( ring )  03:12  Ends 10:45 PM
            ( −  10 min  + )            ← 1-min steps
   ( Reset )                  (● Pause ●)
```
```
overtime   ring full orange · +02:41 orange · "Overtime" · keeps counting
```

## LeetCode
```
‹ More              LeetCode             ⤡
                1. Two Sum▌             ← inline field, centered, no border
        ( Easy ) ( MEDIUM ) ( Hard )    ← small pills; selected tinted by difficulty

               18:04
               Solving                  ← Ready / Solving / Paused

   ( Reset )                  (● Start ●)

HISTORY               12 · avg 21:40 · best 09:12
1. Two Sum                              18:04
● Medium · Sep 25
146. LRU Cache                          41:12   ← swipe left → Delete
● Hard · Sep 24
─────────────────────────────────────────────────
[[              Finish & Save              ]]  ← bottom bar, enabled once time > 0
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
│              44 : 12        ← thin rounded digits, fill width │
│                  ◔ Overtime  ← countdowns: small ring + note  │
│                                                              │
│  (✕)                                    ( Reset ) (● Start ●)│ ← dimmed, compact round buttons
└──────────────────────────────────────────────────────────────┘
  portrait bottom (home indicator) is on the right edge
```
- Same live value + colors as the page: stopwatch hundredths; Interview red `00:00` at zero; Rehearsal orange `+mm:ss`.
- Controls: Start/Pause(Stop), Reset or Lap (stopwatch, running), ✕ closes.
- Screen stays awake while shown; black background; status bar + home indicator hidden.
