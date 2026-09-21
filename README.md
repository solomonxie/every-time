# Every Time

> 🚧 Work in progress — skeleton only, not yet functional.

Everything about time, in one free iPhone app: world clock across multiple
zones, a global meeting-time overlap lookup, a set of purpose-built timers
(general, LeetCode with persistent history, interview, reversal), and
sleep tools based on actual sleep science rather than a flat "8 hours" —
an ideal wake-up time calculator, a REM-cycle-based sleep alarm, and
Timeshifter-style jet lag adjustment. Also folds in smaller utilities like
movement/stand-up reminders and looking up real-world waiting/queue times
from public data.

## Features

- **Clocks** — multi-timezone world clock, global meeting time lookup
- **Timers** — general purpose, LeetCode (persistent history), interview,
  reversal
- **Sleep** — ideal wake-up calculator, REM-cycle sleep alarm, jet lag
  adjustment
- **More** — movement reminders, waiting/queue time lookup, about

## Setup

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```
xcodegen generate && open EveryTime.xcodeproj
```

## Roadmap

- Apple Watch companion app (time-at-a-glance, timers)
- Home-screen widget (current time across saved zones)
- Real timer/clock logic and local persistence
