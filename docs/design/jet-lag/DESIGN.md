# Jet lag planner — design

UI: [UIUX_DESIGN.md](UIUX_DESIGN.md) · Build: [IMPLEMENT_PLAN.md](IMPLEMENT_PLAN.md) · Reference: Timeshifter

## Problem

Crossing time zones leaves the body clock hours off for days. Generic advice
("sleep on local time") ignores *when* light helps vs hurts. Timeshifter solves
it with timed actions but is paid; Every Time should offer a free, offline plan.

## Goals / Non-goals

- Personal day-by-day plan: see bright light / some light / avoid light, sleep,
  nap-if-you-can, caffeine OK / avoid, optional melatonin — each with a time window.
- Adjust before departure (0–3 days), during travel, and after arrival until adapted.
- Local notifications at the start of each action.
- Non-goals: multi-leg trips and flight-number lookup (v2 — needs a paid flight API; v1 = manual times), shift-work plans, wearables/HealthKit input, medical dosing advice.

## Model (all times as UTC instants, displayed in the tz the user is in that day)

| Concept | Rule |
|---|---|
| Body-clock anchor | CBTmin (core body temp minimum) = habitual wake − 3h; age ≥ 60 → −2.5h |
| Chronotype | early −0.5h / late +0.5h on CBTmin; late types advance ×0.85, delay ×1.1 |
| Required shift Δ | dest-aligned CBTmin − current, wrapped to (−12, 12]; − = advance (east) |
| Direction | advance a h or delay 24−a h — pick fewer days (advance 1.0 h/day, 1.5 with melatonin; delay 1.5 h/day); ties → advance |
| Age | ≥ 60 → rates ×0.8 |
| Advance day | bright light CBTmin → +3h · some light +3 → +5h · avoid light −4h → CBTmin · melatonin 0.5 mg at CBTmin − 9.5h |
| Delay day | bright light CBTmin −3h → CBTmin · some light −5 → −3h · avoid light CBTmin → +4h · no melatonin |
| Light vs own sleep | windows before/after CBTmin that fall in that night's sleep slide as a group to just before bed / after wake (order + length kept) |
| Sleep | wake = CBTmin + (habitual wake − habitual CBTmin) (3h default), bed = wake − usual sleep length; shifts every day incl. pre-flight |
| Caffeine | OK wake → bed − 8h · avoid bed − 8h → bed |
| Travel day | part of a sleep window inside the flight → "sleep if you can"; nap 25 min when the gap between regular sleeps > 18h and spans the flight — in the post-flight awake stretch (≥ 4h) else the longest one |
| Clipping | light/caffeine windows overlapping any sleep are cut; past actions are kept (history) |
| Adapted | remaining |Δ| < 0.5h → final day shows sleep only, plan ends (≥ arrival day, max 14 days); |Δ| < 0.5h at start → no plan |

Sex is asked (Timeshifter does) but v1 applies no adjustment — evidence is weak; kept for later tuning.

## Options considered

- Copy Timeshifter's algorithm → impossible (proprietary); **published PRC-based model** instead, documented above so it can be tuned.
- Server-side plan → **on-device**; pure function of profile + trip, offline, private.
- Remote push → **local notifications** (UNUserNotificationCenter), rescheduled on launch; iOS caps 64 pending, so schedule the next 60.

## Data

`sleep.jetlag.profile` (age, sex, chronotype, usual bed/wake, melatonin, caffeine, notifications),
`sleep.jetlag.trips` ([origin tz, dest tz, depart, arrive, pre-adjust days]). `sleep.` prefix ⇒ included in backups.

## Risks

- Not medical advice; melatonin legality/dosing varies — shown behind ⓘ, melatonin off by default.
- Model is a simplification; plans may differ from Timeshifter's.
