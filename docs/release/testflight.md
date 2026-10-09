# TestFlight external testing

App Store Connect → TestFlight → External Testing → **+** group → add the build. First build of a version goes through Beta App Review (~1 day).

## Test Information

Beta App Description (≤4000):

```
Every Time is a set of time tools in one app: world-clock planner, sleep cycles and nap alarm, a day log, jet-lag planner, Chinese lunar calendar, countdowns, and a drawer of timers and developer time tools.

No account. For sample data on every screen: More tab → Demo mode (a separate store; your own data untouched; it does not read Health).

What's in this beta:
• World: time-zone planner with shared hour strips and working-hour overlap
• Sleep: cycle and nap planner, an alarm that rings in silent mode, sleep log and score (optional read-only import from Health)
• What did: a day log on a drag-through timeline
• Jet lag planner
• Chinese lunar calendar with converter and events
• Countdowns, important events, "On this day" (from Wikipedia)
• Stopwatch, interview / rehearsal / LeetCode / work timers, Unix timestamp and cron tools
• Widgets: world clock and next countdown
```

Feedback Email: `you@example.com`

## Contact Information

| Field | Value |
|---|---|
| First Name | TODO |
| Last Name | TODO |
| Phone number | TODO — yours, with country code (`+1 …`) |
| Email | `you@example.com` |

## Sign-In Information

Sign-in required: **off** (no account in the app). Leave User Name / Password blank.

Review Notes (Beta App Review Information):

```
No account or login. For sample data on every screen: More tab → Demo mode. HealthKit is read-only Sleep Analysis, requested only from Sleep → "Add nights from Health". Background audio is used solely so the nap alarm can ring at the set time while the phone is locked.
```

## Per build: What to Test

```
Turn on More → Demo mode and walk every tab. Then with demo off: add two cities in World and read the overlap; set a nap alarm for 2 minutes, lock the phone with the mute switch on, and confirm it rings; log something in What did; add a countdown and put the widget on your Home Screen. Report anything wrong, especially an alarm that didn't ring, with a screenshot via TestFlight.
```
