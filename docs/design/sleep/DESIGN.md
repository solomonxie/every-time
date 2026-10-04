# Sleep — redesign

Stories: [STORIES.md](STORIES.md) · UI: [UIUX_DESIGN.md](UIUX_DESIGN.md) · Build: [IMPLEMENT_PLAN.md](IMPLEMENT_PLAN.md)

## Problem

The page is built around *planning* a night: drag bed and wake handles, add naps to the ring,
tap `Set alarm`, land in a "until bed" countdown, tap `I'm in bed now`, then sleep. Three taps
and two intermediate states for the one thing people open it for — "I'm sleeping now, wake me
well". `Set alarm` reads as a commitment to a mode, not to sleep; the planned-nap lane, the
planning pin and the wind-down countdown are states most sessions never use but every session
has to read past.

## Goals

- **Readable half awake.** Most opens are at bedtime, at 3 AM or right after the alarm: one
  glance says what's happening; night states are dark and dim; doing nothing is always safe.
- S1/S2 in one tap, on the same page, nothing to confirm after; going back to sleep is zero taps.
- One page, no pushed screens, no modal flow; the page's top always answers "what now?".
- Every state (idle, asleep, ringing, just up) shows at most two buttons, the primary in the same
  place every time.
- Keep the cycle picture: the ring, deep-sleep shading, "wakes between cycles".

## Non-goals

- Several planned naps on the ring. One sleep at a time.
- Sleep tracking / stages — Health does that; we read it.
- Jet lag — its own tool, untouched.

## Options considered

- **A. Keep the planner, rename `Set alarm` → `Sleep now`** — the label isn't the problem; the
  bed-later / wait-for-bed states are.
- **B. `Sleep now` button, drop the ring** — loses the only thing that makes a cycle visible;
  wake chips alone are a list.
- **C. `Sleep now`, ring anchored at now, one draggable end (the alarm)** — tried first; lost
  planning tonight's bed and the wake moved with the pick. Rejected on the phone.
- **D. `Sleep now`, bed handle (now by default) + alarm handle, both sticky** — bed at now is one
  tap; bed later is the same tap, which plans the night on the same page. **Chosen.**
- Planning ahead: separate countdown page (before) · one-tap reminder only (C) · the plan stays
  on the page with the ring counting down to bed (D) → **D**.
- Button label: always `Sleep now` · follows the pick (`Nap now` / `Sleep now`) →
  **follows the pick**, with the wake time in the label so the tap is never a surprise.

## Decision

D. Idle page = bed / wake readouts → ring (bed → alarm) → wake chips → one button. Bed = now:
`Sleep now · up at X` starts `NapSession` at once. Bed later: `Bed at B · up at X` plans it —
the night screen counts down to B and becomes Asleep by itself (`Asleep already` if earlier).
Cancel returns to the page with B and the wake still set. Bed and wake persist until they pass. The pick comes from `SleepNow` (nap by day, whole cycles
before the usual wake by night) and only fills in a wake the user hasn't set.

## Data

- Unchanged keys: `sleep.naps`, `sleep.nap.active`, `sleep.caffeine`, profile, cycle.
- Replaced: `sleep.ring.night` / `sleep.ring.naps` → `sleep.plan.bed` / `sleep.plan.wake` (the sticky picks).
  Removed: `sleep.nap.night` (`NightPlan`; never written since the ring).
- Wind-down reminder stays a single local notification (`sleep.winddown`), scheduled with a
  planned bed, cancelled when the sleep starts.

## Risks / open questions

- `Sleep now` at 7 PM is a split night; it stays available (red chip, red verdict) — the app
  advises, it doesn't block.
- The `Nap 90` default on late-night days (`NapAdvice.suggestedMinutes(on:)`) depended on
  `NightPlan`; with no plan it's always 20. Acceptable.
