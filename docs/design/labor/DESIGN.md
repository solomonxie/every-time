# Labor

Research: [RESEARCH.md](RESEARCH.md) · UI: [UIUX_DESIGN.md](UIUX_DESIGN.md) · Build: [IMPLEMENT_PLAN.md](IMPLEMENT_PLAN.md)

## Problem

In late pregnancy the questions at 3 AM are "is this real labor?", "when do we go?", "is something wrong?". Answering them by hand means timing contractions on a stopwatch, doing arithmetic on scraps of paper, and remembering what time the waters broke. Generic timers record the numbers but don't read them.

## Goals

- One huge Start/Stop. A partner can use it half asleep, one-handed, mid-contraction.
- Answers from the numbers, with their reasons shown: the pattern (Braxton Hicks-like / early / active-like), whether the go rule is met, and the trend.
- Red flags override everything, always one tap from calling the hospital.
- Every tap saved at once. Survives app kill, reboot, a phone change (backup).
- A summary to read out or send to the midwife.

## Non-goals

- Diagnosis. Phases are defined by the cervix, and the app says so.
- Kick counting, a pregnancy diary, Health sync, a watch app, notifications.
- Comparing pregnancies. Each labor is its own profile; past ones are kept, not analysed together.

## Options considered

- **Contraction timer only.** Waters, bleeding and movement would live nowhere, yet they change the advice more than any timing does.
- **Labor tool: contractions plus events on one timeline.** **Chosen.**
- **Plus a kick counter.** It covers weeks, not hours. NHS: don't count, call if the baby moves less, so it's a red-flag event here.

## Decision — analysis rules

Everything is computed from the **current episode**: contractions with no gap over 3 h. An older run is history.

**Clean data.** The phrase "doesn't count" means the contraction is shown but left out of stats.
- A stop under 10 s is a mis-tap and doesn't count.
- A length over 3 min is "forgot to stop" and doesn't count. Between 2 and 3 min counts, and it's a red flag.
- Strength is optional.
- Medians, not means, so one missed tap can't swing the result.

**Window.** The last 60 min, ending now. Trend = this hour vs the hour before.

**Go rule**, derived from setup (`LaborSettings.plan`), first match wins:
| Answer | Rule |
|---|---|
| Care team gave a rule | theirs |
| Previous labor under 3 h | 10-1-1 |
| Over 30 min to get there, ride wait included | 10-1-1 (INSPQ) |
| Not first baby | 5 min apart · 1:00 · 20 m (INSPQ: no full hour) |
| First baby | 5-1-1 |

Health conditions (GBS, previous or planned C-section, twins, breech, high blood pressure, "come in early") add **first sign**: call once contractions turn regular, without waiting for the rule.

Met when, over the rule's window:
- tracking started at least a full window ago, and the window holds ≥4 intervals;
- median interval ≤ rule interval, and ≥80% of intervals ≤ rule interval + 1 min;
- median length ≥ rule length − 5 s.
Otherwise the screen shows progress: each condition ✓/✗ with its value, and one line on why when the value alone doesn't say (too few gaps, too few near the goal).

**Pattern** (timing only, always captioned "by timing — not an exam"):
| Label | When |
|---|---|
| Keep timing | <5 counted contractions or <20 min in the window |
| Like Braxton Hicks | ≥2 BH signs and no labor sign |
| Early labor-like | regular, median interval >5 min |
| Active labor-like | regular, interval ≤5 min, length ≥40 s |
| Very close together | regular, interval ≤3 min, length ≥60 s |
| Unclear | anything else |

Thresholds:
- Regular: CV of intervals ≤0.30. Irregular: CV ≥0.45. Both cut-offs are the app's own; no clinical standard exists.
- BH signs: irregular · no shortening over ≥1 h (this hour's median interval ≥ last hour's − 30 s) · mostly mild (≥70% of rated) · eased after "Rested" (rate in the 30+ min after < half the rate in the hour before).
- Labor signs: regular · interval shortened ≥1 min hour over hour · length rising · mostly strong.

**Red flags** (red banner with "Call now", above everything, in this order):
- Baby coming (urge to push, cord visible): dials the emergency number, not the hospital.
- Waters broke: "call soon" if GBS+ or green/brown/smelly, otherwise "let your team know".
- Bleeding.
- Baby moving less.
- Contraction >2 min.
- ≥6 in 10 min.
- Before 37 weeks with ≥4 in the last hour. This also blocks any "Braxton Hicks" reassurance.
Wording is "worth a call", not alarm: the colour and position carry the urgency. The CDC warning signs are in the guide (ⓘ) and Details.

**Stages.** The bar runs Before → Early → Active → Hospital → Born. You can tap any stage, skip ahead or go back. No order is forced: waters break before contractions in only ~1 in 10 term births ⚠. Each pick is saved as a timed event.
- Suggestions:
  - Before → Early when the pattern is regular.
  - → Active when the go rule is met.
  - Never past Active: arriving and the birth are facts only you know.
- "Not yet" hides a suggestion for 30 min.
- At the hospital and after the birth, no call banners show.
- Born: you confirm, it saves the birth time, stops a running contraction, and labor length counts from the first Early/Active pick or the first contraction.
- Advice follows the picked stage: at Active it says go, never "rest at home".

## Data & integrations

- **Profiles, one per labor:** `timers.labor.profiles` holds `[LaborProfile]` (name, settings, contractions, events). `timers.labor.current` is the chosen id. Written on every tap.
- **New labor** (Settings › Labors, or "Start over" after a birth): a new profile that keeps hospital, phone, emergency number and travel; sets "not first baby"; asks setup again.
- **Per profile:** a get-ready checklist (`prep`; the plan and phone items tick themselves) and the last "Not yet" (`notYet`).
- **Setup:** `setupDone` after Done; `setupSkipped` after Later, which leaves a "Finish setup" row.
- **Reset plan settings** clears the answers and reruns setup; the timeline stays.
- **Migration:** the pre-profile keys (`timers.labor.contractions/events/settings`) move into "My labor" once, at launch, on foreground and after a restore. Unreadable bytes are never deleted.
- The `timers.` prefix → local and iCloud Drive backups, restore on reinstall (`EveryTime/Backup/README.md`).
- Counted in backups as "labor(s)".
- `tel:` link to the stored hospital number. No network, no notifications.

## Risks

- Labelling: the app could be read as diagnosing. Mitigation: phrasing "-like", the red flags first, "your care team's advice wins" stated on the screen.
- Preterm. Mitigation: the due date is asked for in setup; without it the pregnancy card says the preterm check is off. Dates outside 0–44 weeks are ignored.
- Battery over a long labor. Mitigation: the screen refreshes every second only while a contraction runs, and stays awake only while an episode is live.
