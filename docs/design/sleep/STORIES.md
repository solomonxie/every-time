# Sleep — user stories

Each: **when** · wants · done when. Taps count from the Sleep tab already open.
Mocks that satisfy each story: [UIUX_DESIGN.md](UIUX_DESIGN.md).

**The reader is half awake.** Most opens are at bedtime, in the middle of the night or right
after the alarm. Every story is judged on: one glance says what's happening; as few taps as
possible; doing nothing is always safe.

## Core — one tap, nothing to confirm

- **S1 Going to bed now** — 11:20 PM, in bed, usual wake 7:00. Wants the best wake before 7. Done: glance "Up at 6:35 AM", tap `Sleep now` → asleep. **1 tap.**
- **S2 Nap now** — 2:10 PM, post-lunch dip. Wants a 20-min nap, up fresh. Done: tap `Nap now` → asleep, alarm 2:30 PM. **1 tap.**
- **S3 Different wake tomorrow** — 11:00 PM, flight, must be up at 5:00. Done: tap the `5:00 AM` chip (or the WAKE UP readout → wheel for an odd time), then `Sleep now`. **2 taps.** Stays at 5:00 until it passes; usual hours untouched.
- **S4 Specific nap length** — 3:00 PM, late night ahead. Wants a full 90-min cycle. Done: `Nap 90` chip, `Nap now`. **2 taps.** Page says what it does to tonight.

## While asleep — half awake, in the dark

- **S5 Woke at 3 AM** — alarm 6:35, mind blank. Wants to know whether to get up or sleep on. Done: black screen, big "3:12 AM", "Alarm 6:35 · in 3h 23m", one line "Mid-cycle · sleep on". Lock the phone. **0 taps.** Screen is dim enough not to wake anyone.
- **S6 Alarm rings** — stop it and go. Done: one button `I'm up`, on the lock screen or in the app; the sleep is logged. **1 tap.**
- **S7 Sleep a bit more** — alarm rang, one more cycle fits before 8:00. Done: tap `+1 cycle · 8:05` → asleep again. **1 tap.**
- **S8 Change of plan** — nap started, phone rings. Done: `Cancel` (first 15 min), toast with Undo; nothing logged. **1 tap.** After 15 min Cancel is gone — a sleepy thumb can't drop the night.
- **S9 App opened at night on another tab** — launching lands on Sleep while a sleep is active. **0 taps** to get there.

## Around the night

- **S10 Bed later tonight** — 9:00 PM. Bed at 11, up at 6:35. Done: drag 🛏 to 11:00 (or tap the readout → wheel), `Bed at 11:00 PM · up at 6:35 AM`. **2 taps.** Night screen counts down to bed, wind-down reminder at 10:30, asleep by itself at 11 (`Asleep already` if earlier). Cancel keeps 11:00 / 6:35 set.
- **S11 Wrong hour** — 7:00 PM wanting to sleep for the night → red split-night line, can still do it. 1:30 AM → wake times that still fit before 7:00. **1 tap** either way.
- **S12 Morning after** — first open after waking, half awake. Done: `Good morning · 7h 13m · 5 cycles`, three big feel buttons, optional. **0–1 tap.**
- **S13 Forgot to tap** — slept without the app. Done: morning card "Did you sleep last night? `Yes · 11:00 PM – 7:05 AM`" (Health-filled when connected). **1 tap.**
- **S14 Coffee** — 3:00 PM, can I? "Coffee OK until 3:00 PM" in the day verdict; log a cup in the tile. **0–1 tap.**
- **S15 Weekly review** — how am I doing? Scroll: score trend, debt, nights, naps. **0 taps.**
- **S16 First run** — no profile. Defaults 11 PM–7 AM apply; one line offers to set hours, or to take them from Health. `Sleep now` already works. **1 tap** to sleep.

## Alarm reliability

- **S17 Silent / Focus** — the alarm still rings (AlarmKit on iOS 26; in-app ringer + notifications before). Notifications off → the warning sits under the chips *before* the tap, with `Turn on`.
- **S18 App swiped away** (pre-iOS 26) — the notification chain still fires; `I'm up` on the banner logs the sleep.
