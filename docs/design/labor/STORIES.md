# Labor — user stories

Who uses it, and the paths it has to handle. Design: [DESIGN.md](DESIGN.md) · UI: [UIUX_DESIGN.md](UIUX_DESIGN.md)

## People

| Who | Situation |
|---|---|
| P1 Partner, first baby | Never seen labor. Near the hospital, drives |
| P2 Mother, second baby | Last labor was 4 h. 45 min away |
| P3 Couple without a car | Rideshare at night |
| P4 GBS positive | Told: come in when waters break or labor starts |
| P5 Previous C-section (TOLAC) | Told: call at first sign |
| P6 34 weeks, tightenings | Worried it's preterm labor |
| P7 Twins / breech / planned C-section | Any labor sign means go |
| P8 Mother timing alone | Partner away; one hand, phone on the bed |

## Stories

### Setup (once, weeks before)
- **S1** As P1, I want the app to ask me a few plain questions and build our plan, so I don't need to know any rules.
  - Steps: first baby? → due date → hospital name + phone → how far, how we get there → what did your care team say → health conditions → plan read back in one paragraph.
  - Edge: I skip every question → 5-1-1 default, and "Add the hospital's number" stays visible on the screen.
- **S2** As P2, I want a later baby, a fast last labor and a long drive to make the plan go earlier, so we don't deliver in the car.
  - Result: plan "call at 10 min apart" (far or fast labor), and the reason is shown.
- **S3** As P3, I want the time to get a ride counted, so "leave now" comes early enough.
  - Result: rideshare adds 15 min, a pick-up adds 15 min, to the travel time.
- **S4** As P4/P5/P7, I want to tick my condition so the app tells me to call at the first sign, not wait for 5-1-1.
  - Result: when the pattern turns regular, or waters break, the advice says "Call now — your plan says first sign".
- **S5** As anyone, I want to type the rule my care team gave me, so theirs replaces the app's.
- **S6** As anyone, I want to re-run setup or change one answer later, and see the plan as one sentence.

### Labor
- **S7** As P1 at 2 AM, I want the stage bar, one button and one sentence telling me what to do.
- **S8** As P6, I want contractions at 34 weeks treated as "call now" when there are ≥4 an hour, never "probably Braxton Hicks".
- **S9** As P1, after a false alarm (irregular, eased after rest), I want "probably practice contractions" with reasons.
- **S10** As anyone whose waters break first, I want logging it to say "call now", record the colour, and keep timing.
- **S11** As P2, I want "leave now" to fire on my earlier rule, with the drive time named.
- **S12** As anyone sent home from triage in early labor, I want to step back to Early without losing anything. It's normal.
- **S13** As anyone whose baby is coming fast (urge to push), I want one button for the emergency number, not the hospital.
- **S14** As P8, I want everything reachable one-handed, with nothing typed during labor.
- **S15** As anyone at the hospital, I want the summary in the midwife's terms (minutes apart, length, since when, waters).
- **S16** As anyone after the birth, I want the time stamped and the labor kept, and backed up.

## Use cases

| # | Trigger | Expected | Failure / edge |
|---|---|---|---|
| U1 | first open | "Set up your plan" card above everything; Skip possible | skipped → a small "Finish setup" row stays |
| U2 | setup: not first, last labor <3 h | plan → call at regular contractions (10-1-1) | — |
| U3 | setup: 50 min drive | plan → 10-1-1, "Far from the hospital" | travel 0 or blank → ignored |
| U4 | setup: GBS+ | waters event → red banner "With GBS, give your care team a call soon — antibiotics work best started early" + Call now | — |
| U5 | setup: twins / breech / planned C-section / previous C-section | first regular pattern → "Call now (first sign)" | Braxton Hicks-like → still "call if unsure" |
| U6 | care-team rule 4-1-1 | replaces the derived rule; labelled "Your care team's rule" | — |
| U7 | rule met | advice "Call the hospital, then leave — about 40 min by car" | no phone → "Add number" |
| U8 | "Urge to push / baby coming" event | red banner + emergency number (911 / 120) | — |
| U9 | Hospital → back to Early | stage history shows both; timing resumes | — |
| U10 | settings opened during labor | plan sentence on top; every answer one tap from its question | — |
