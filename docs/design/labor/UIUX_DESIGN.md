# Labor — UI/UX

Why: [DESIGN.md](DESIGN.md). Tool page `LaborView`, reached from More → Timers → Labor (pinnable).

## Stories

- S1 As her partner, I want one big button to time a contraction, so I can do it in the dark mid-contraction.
- S2 As a couple, we want to know whether this is Braxton Hicks or labor, and why the app thinks so.
- S3 We want to know when our go rule is met, and how close we are.
- S4 We want waters breaking, bleeding or less movement to tell us at once to call.
- S5 We want to fix a mis-tap.
- S6 We want to read the last hour out to the midwife, or send it.
- S7 We want nothing lost if the app is killed or the phone is replaced.

| Story | Trigger → result | Edge |
|---|---|---|
| S1 | tap Start → the timer runs; tap Stop → saved, strength chips unfold | double tap within 0.5 s ignored; app killed mid-contraction → still running on reopen |
| S2 | ≥5 contractions → pattern card with its reasons | <5 → "Keep timing", count needed |
| S3 | rule card: 3 conditions, each ✓/✗ with value | rule met → green card + haptic, Call shown |
| S4 | Waters… / Bleeding / Moving less → red banner with Call | no phone set → banner offers Set number |
| S5 | running: Discard; past: swipe to delete (Undo), tap to edit; edits that overlap another contraction can't be saved | contraction left on >3 min → "Forgot to stop?" |
| S6 | share icon → text summary | empty → disabled |
| S7 | every tap saved; iCloud Drive backup | — |

## Screen

One answer first, one button, three numbers. The reasons, the hour-by-hour table and the chart sit behind Details.

```
‹ More          My labor          ?  ⇪  ⚙        ← title = the chosen labor; switch it in ⚙
⚠ Waters broke 2:41 AM — green. Call now  [ Call ]   ← red flags only; red, top, stacked
╭ 38 weeks 2 days  [Early term]                    ╮    ← pregnancy card, until Hospital; ACOG terms
│ Due in 12 days · Oct 30, 2026                     │      preterm <37 · early 37–38 · full 39–40
│ Baby could come any day now. Keep the phone …     │      · late 41 · post 42+; tip per week
│ Get ready  5 of 7                              ›  │    ← checklist, kept per labor; "plan" and
╰───────────────────────────────────────────────────╯      "phone" tick themselves from settings
 no due date → ( Add the due date to see the weeks and what to get ready )
 Before ── Early ── Active ── Hospital ── Born           ← tap = preview only (dashed ring), nothing saved
╭ Just looking at Active labor — nothing is saved. ╮     ← + that stage's card right below
│ ( Back to Early )              [[ We're here now ]]│     ← records it; Born asks once more
╰───────────────────────────────────────────────────╯
   ✓        ●
╭ Contractions are regular now.          ╮              ← suggestion; "Not yet" hides it 30 min
│ Move to Early labor?  ( Not yet ) [[Yes]]│
╰──────────────────────────────────────────╯
Getting close. Keep timing.                          ← advice headline, tinted by tone
Regular and close together. Call when all            ← one plain sentence
three goals are met.
╭───────────────────────────────────────╮
│        Contraction in progress        │            ← red while timing
│                0:42                   │
│          Tap when it ends             │
╰───────────────────────────────────────╯
                     ( Tapped by mistake )
╭ Hospital rule 5-1-1: call when all three are ✓ ╮
│ Apart        Each lasts      Timed for          │
│ 4:50 ✓       0:48            38 m               │
│ goal ≤ 5:00  goal ≥ 1:00     goal 1 h           │
╰─────────────────────────────────────────────────╯
( + Waters, bleeding, other… )   ( Details )
╭ You're here: Early labor                       ╮      ← stage card: happening · do now · move on when
│ DO NOW • Stay home: rest, eat light, drink …   │
│ MOVE TO ACTIVE WHEN • They're 5:00 apart …     │
╰────────────────────────────────────────────────╯
TIMELINE
 Saturday, Oct 18   12 contractions             ⌄   ← by day; today + yesterday open
 3:12 AM   Lasted 1:02                    Strong
           4:50 after the one before
 3:10 AM   ⚑ Early labor
 2:41 AM   💧 Waters broke · green
 Thursday, Oct 2    14 contractions             ›   ← older days folded; swipe/hold → Delete day
Tap a row to fix it (events: their time). Swipe left or long-press to delete; Undo shows for 4 s.
```

Born: the button, goals and advice give way to "Born at Oct 18, 6:40 AM · 9 h of labor · 84 contractions timed" and ( Start over for a new labor ) → a new profile; this one stays in Settings › Labors.

## States

```
first run     ╭ Timing contractions — how it works ╮   ← inline until the first tap; ⓘ in the toolbar after
              │ ① When she feels a contraction      │
              │   start, tap the big blue button    │
              │ ② When it ends, tap it again …      │
              │ ③ Repeat … ④ This spot tells you … │
              │ ⑤ Waters broke …? Tap "Waters…"     │
              ╰─────────────────────────────────────╯
              [[ ✋ Tap when a contraction starts ]]   blue
resting       Last one started 3 m ago, lasted 1:02.
              How strong?  [ Mild ] [ Moderate ] [ Strong ]   ← 15 min after it ends
over 3 min    Forgot to tap?  ( End it at 1:00 )  ( Tapped by mistake )
advice        Tap Start… · Keep timing. · Probably practice contractions (Braxton Hicks).
              · Probably early labor. Rest at home. · Getting close. Keep timing.
              · Very close together. Get ready to go. · Time to call the hospital. [ Call ]
              · Call your care team now. (any red flag)
```

Details sheet: Looks like + reasons (↗ labor / ⏸ practice) · last hour vs the hour before · chart · how it works.

## Overlays

```
What happened? (dialog)            Edit contraction (sheet)
 Waters broke… · Bleeding · Mucus plug / show · Baby moving less · She rested or drank water · Write a note…

 What colour was the water?              Started          3:12 AM ›
 ( Clear )                           Length        [−] 1:02 [+]
 ( Pink )                            Strength [ Mild | Moderate | STRONG ]
 ( Green or brown )!                 ( Delete )!
 ( Smelly )!
 ( Not sure )

Settings: see Setup below.
```


## Setup (sheet, first open + "Go through setup again")

Stories S1–S6 ([STORIES.md](STORIES.md)). One question per page; Next keeps what's shown; the due-date page has "Don't know yet"; answers save as you go.

```
Close        Set up your labor plan
[████░░░░░░░░] Step 4 of 7
How long does it take to get there?
Door to door, at night. Far away means you leave earlier.
[ 10 ] [ 20 ] [[ 30 ]] [ 45 ] [ 60+ ]   min
About 30 min                    [−][+]
How will you get there?
╭ Our car — someone else drives      ● ╮
╭ Taxi or rideshare                  ○ ╮       ← +15 min wait
╭ Someone picks us up                ○ ╮
╭ Walk — it's very close             ○ ╮
( Back )                 ( Skip )  [[ Next ]]
```

Pages:
1. First baby? → was a previous labor under 3 h?
2. Due date (calendar).
3. Hospital name, labor phone, emergency number.
4. Travel time and transport.
5. Health ticks (GBS, previous C-section, twins, breech, planned C-section, high blood pressure, care team said come early, none).
6. Care team rule (no / yes + steppers).
7. Your plan:

```
Your plan
╭ Call St. Mary's when contractions are 10:00 apart or closer, each 1:00 long, for 1 h.  ╮
│ It takes 45 min to get there, so go early. Because of GBS positive: call at the first   │
│ sign of labor. GBS positive: antibiotics should start early in labor.                   │
│ Getting there takes about 45 min by taxi.                                                │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
Always call at once if waters break, there's bleeding, the baby moves less…
⚠ No hospital phone yet — Call buttons will ask for it.         ← only if empty
( Back )                                   [[ Done ]]
```

Main screen, until setup is done or skipped:

```
╭ Set up your labor plan                                  ╮
│ 7 quick questions — first baby, hospital, how far…      │
│ [[ Start setup ]]                            ( Skip )   │
╰─────────────────────────────────────────────────────────╯
```

## Settings (sheet, ⚙) — "Labor settings"

```
Labor settings                              Done
LABORS
 My labor                                ✓      ← tap to switch
 Started Oct 18, 2026 · 84 contractions
 Labor 2, 2028
 Started Mar 2, 2028 · 0 contractions
 Name                              My labor     ← renames the ✓ one
 + Start a new labor
 Delete "My labor"…!                            ← only with 2 or more
 Each labor — one per pregnancy — keeps its own plan, contractions and events…
YOUR PLAN
 Call St. Mary's when contractions are …          ← the plan sentence
 Go through setup again
BABY
 First baby?                         Yes ⌄
 A previous labor was under 3 hours   ○─        ← only if not first
 I know the due date                  ─●
 Due date                      Nov 20, 2026
 Today                     38 weeks 2 days
HOSPITAL
 St. Mary's
 Labor phone                     555 0101
 Emergency                            911
GETTING THERE
 Travel time: 45 min               [−][+]
 Going by              Taxi or rideshare ⌄
HEALTH
 Group B strep (GBS) positive         ─●
 Previous C-section                   ○─   …
WHEN TO CALL
 My care team gave me a rule          ○─        → three steppers
( Delete all contractions and events )!
```

Each section's footer says in one line what its answers change.

Deviations from the `uiux` skill: none.
