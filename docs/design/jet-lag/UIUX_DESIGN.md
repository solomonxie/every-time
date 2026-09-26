# Jet lag planner — UI/UX

Product: [DESIGN.md](DESIGN.md). Its own tool, "Jet lag planner" (tab label "Jet lag").

## Screen map

```
Jet lag ─ no profile ──▶ Profile form (sheet, first run)
        ─ Trips list ─ tap ──▶ Plan (pushed)
                     ─ [[ Plan a trip ]] ──▶ New trip (sheet)
        ─ Your sleep card ──▶ Profile form (sheet, edit)
```

## Trips list, profile form, new trip

Redesigned — see [iphone-v1/uiux/sleep.md](../iphone-v1/uiux/sleep.md).

## Plan (pushed) — mirrors Timeshifter's day timeline
```
‹ Sleep     Vancouver → London          🔔
☀ bright  ☀ some  ⊘ light  ☕ ok  ⊘☕  🌙 sleep  💊      ← legend chips
─────────────────────────────────────────────────
Thu, Oct 29 · Vancouver           day 1 · −1h
      │  light   caffeine   sleep
 6am  │   ▓▓       ▒▒                ← ▓ yellow bright, ▒ brown caffeine
 7am  │   ▓▓       ▒▒
 …    │   ░░ orange some-light
 3pm  │            ┌┐ avoid caffeine (outline)
10pm  │   ⊘                  ██      ← navy sleep bar
─────────────────────────────────────────────────  day separator (hatched)
Sat, Oct 31 · Vancouver → London   ✈ 6:40 PM
      │ ✈ flight bar (grey) spanning hours, sleep-if-you-can = light navy
─────────────────────────────────────────────────
Wed, Nov 4 · London                 Adapted 🎉
```
- One column per category (light · caffeine · sleep/nap · melatonin dot); bars are capsules with the icon at top (as Timeshifter).
- Hour axis = local time of where the user is that day; a red now-line on today; opens scrolled to now.
- Tap a bar → popover: "See bright light · 7:00–10:00 AM · Go outside or use a light box."
- 🔔 toolbar toggles notifications for this trip.

## Notification copy
| Action | Title | Body |
|---|---|---|
| bright light | ☀️ See bright light | Until 10:00 AM — get outside or near a window |
| some light | 🌤 Some light is fine | Until 12:00 PM |
| avoid light | 🕶 Avoid bright light | Until 7:00 AM — sunglasses, dim room |
| caffeine avoid | ☕️ No more caffeine | Until bedtime at 11:00 PM |
| sleep | 🌙 Time to sleep | Wake at 7:00 AM |
| nap | 😴 Nap if you can | 20–30 minutes |
| melatonin | 💊 Melatonin | 0.5 mg now |

## Implementation notes
- Styled per `docs/design/iphone-v1/uiux/visual.md`: cards/plain background, one toolbar item (⚙ list, 🔔 plan) — the plan's ⓘ disclaimer sits on the LEGEND label.
- Flight = grey band behind all columns; melatonin = dot in a narrow 4th column.
- Eastbound, the arrival day's early hours are shaded (already shown in the previous band); westbound, the hours between the origin's and destination's midnights get their own continuation band in origin time.

## Deviations from the `uiux` skill
None. Explanations (chronotype, melatonin, disclaimer) are behind ⓘ popovers.
