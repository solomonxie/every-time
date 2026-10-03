# Publishing Every Time — step by step

Every field below is ready to paste. `TODO` = only you can supply it.
App Store Connect paths start at **Apps → Every Time → Distribution →**.

| | |
|---|---|
| Bundle ID | `com.solomonxie.everytime` |
| Widget | `com.solomonxie.everytime.widget` (embedded) |
| Watch app | `com.solomonxie.everytime.watch` (embedded, watchOS 10+) |
| SKU | `everytime-ios` |
| Version | `1.0` (`MARKETING_VERSION`, all targets) |
| Build | timestamp, set by `make release` |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) + Apple Watch — no iPad screenshots needed |
| Min OS | iOS 18.0, watchOS 10.0 |
| Privacy Policy URL | `https://github.com/solomonxie/every-time/blob/master/docs/release/privacy-policy.md` |
| Support URL | `https://github.com/solomonxie/every-time/issues` |

---

## Before you submit — fix or accept

Review risks found in the code. Each is a likely rejection or question.

- [x] **Wait times** (sample data naming theme parks) removed for 1.0.
- [x] **Boards** ("Coming soon") hidden for 1.0: excluded from the build in `project.yml`; Reminders usage string removed.
- [x] **Melatonin**: no dose anywhere; timing only, with "ask a doctor or pharmacist". Age rating → Medical info **None**.
- [x] **Time-sensitive notifications**: `com.apple.developer.usernotifications.time-sensitive` entitlement added (no Apple approval needed; automatic signing adds the capability to the App ID).
- [x] **UIScene lifecycle** (mandatory on iOS 27, also when Review runs this iPhone app on iPad): SwiftUI `App` + `WindowGroup`, no UIKit AppDelegate → already scene-based.
- [x] **Price wording** (Guideline 2.3.7): none in name, subtitle or promotional text; only the description says "free".
- [ ] **Background audio** (`UIBackgroundModes: audio`): on iOS 18–25 a muted loop keeps the app alive until the nap alarm rings → Guideline 2.5.4. Accepted; explained in the review notes below. If rejected, raise the minimum to iOS 26 (AlarmKit only) and remove `audio`.
- [ ] Don't use "LeetCode" or "Wikipedia" in the name, subtitle or keywords (Guideline 2.3.7). The listing below doesn't.

## 1. Apple Developer account

- [ ] developer.apple.com → Account → membership **active** (paid, Individual is fine).
- [ ] App Store Connect → **Business** (Agreements, Tax, and Banking) → no pending agreement banner. Free app: no Paid Apps agreement or banking needed.

## 2. Xcode

- [ ] Xcode → Settings → **Accounts** → signed in with the developer Apple ID; the team shows under it.
- [ ] `cp Local.xcconfig.example Local.xcconfig`, set your Team ID (developer.apple.com → Membership). Gitignored — never commit it.
- [ ] `brew install xcodegen` if missing; `make project` succeeds.

## 3–4. Bundle IDs, App Group, iCloud, HealthKit

Created by automatic signing on device builds. Verify at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers:

- [ ] `com.solomonxie.everytime` → **HealthKit**, **iCloud** (iCloud Documents, container `iCloud.com.solomonxie.everytime`), **App Groups** (`group.com.solomonxie.everytime`), **Time Sensitive Notifications** checked.
- [ ] `com.solomonxie.everytime.widget` → **App Groups** (`group.com.solomonxie.everytime`).
- [ ] `com.solomonxie.everytime.watch` → exists (no capabilities needed; data arrives over WatchConnectivity).
- [ ] `ExportOptions.plist` sets `iCloudContainerEnvironment = Production` at export.

## 5. Run on the iPhone

- [ ] `make device` → paired iPhone. Smoke-test: World (add city), Sleep (nap 10 min → alarm rings, "I'm up"), Add nights from Health, What did (Mark), Lunar (add event to Calendar), Countdown, On this day, Settings → iCloud Drive backup, the widget, the Watch app.

## 6. Create the app in App Store Connect

**Apps → + → New App**

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | `Every Time: World Clock, Sleep` |
| Primary Language | English (U.S.) |
| Bundle ID | `com.solomonxie.everytime` (dropdown) |
| SKU | `everytime-ios` |
| User Access | Full Access |

"Every Time" alone is likely taken; the name above is 30/30. Fallback: `Every Time: Clocks & Sleep` (26).

## 7. Listing content

Fill the pages in [App Store Connect pages](#app-store-connect-pages) below. Screenshots: see [Screenshots](#screenshots).

## 8–9. Archive and upload

```
make release
```

Archives Release (app + widget + watch app, automatic signing), signs for App Store and uploads (`scripts/release-ios.sh`) — no Xcode clicks.
Processing in App Store Connect: 15–60 min, then an email "build has completed processing".

Fallback, Xcode GUI: `make project`, open `EveryTime.xcodeproj` → destination **Any iOS Device (arm64)** → Product → **Archive** → Organizer → **Distribute App** → App Store Connect → Upload.

## 10. TestFlight

- [ ] App Store Connect → **TestFlight** → the build shows no "Missing Compliance" (see [Export compliance](#export-compliance)).
- [ ] Internal Testing → **+** group `Me` → add your Apple ID → install via the TestFlight app on the iPhone; the Watch app installs with it (Watch app → Available Apps if not automatic).
- [ ] Same smoke test as step 5, on the TestFlight build (this is the exact binary Apple reviews). Check iCloud backup specifically — it's the Production container now.

## 11. Submit

- [ ] `iOS App → 1.0 Prepare for Submission` → **Build** → **+** → pick the build.
- [ ] Every page in [App Store Connect pages](#app-store-connect-pages) filled; App Privacy published; Apple Watch screenshots uploaded.
- [ ] **Add for Review** → **Submit for Review**.

## 12. App Review

- Typical: 24–48 h. Status: Waiting for Review → In Review → Pending Developer Release.
- Rejection → **Resolution Center**: reply there, or fix, re-run `make release` (new build number is automatic), attach the new build, resubmit.
- Likely questions: HealthKit use, background audio (see the top section), Wikipedia content.

### Guideline 2.1 "Information Needed" (new developer accounts)

Apple wants a screen recording plus answers 2–6. The answers are the App Review Notes further down — paste them into the reply **and** into App Review → Notes.

Record the build Apple will review. If it's a new build, upload it first (`make release`), pick it under **Build** on the `1.0` page, and install it from TestFlight.

Recording (the build Apple reviews, on the iPhone, current iOS):
1. iPhone Settings → Control Center → add **Screen Recording**. Turn on Do Not Disturb.
2. In the app, More → **Demo mode** on (keeps your real data out; doesn't read Health). Swipe the app away.
3. Start recording, then launch the app from the Home Screen.
4. ~2–3 minutes: World (scroll the hour strips, Add City) → Sleep (tonight's plan, start a 10-min nap, show the alarm screen, Cancel nap) → What did (Mark, tag a range) → Lunar (convert a date, Add event) → More → Jet lag planner (open a trip) → Countdown → On this day → Settings (iCloud Drive backup switch, backups list).
5. Turn Demo mode off, Sleep → **Add nights from Health** → the Health permission sheet (shows read-only sleep), allow → past nights appear.
6. Show the Home Screen widget and, if possible, the Watch app (second recording on the Watch is fine to skip).
7. Stop. Photos → trim → share the video.

Reply: `App Review` in App Store Connect → the message → **Reply**, attach the video (or an unlisted link if too large), paste:

```
Hello, thank you for the review. Answers below, and the same text is now in the App Review Information notes.

1. Screen recording attached, captured on an iPhone running the latest iOS, starting from launch. The app has no account registration or login (so no account deletion flow), no user-generated content shared with others, and no paid content.

[paste the App Review Notes block from PURPOSE AND AUDIENCE to the end]
```

## 13. Release

- [ ] Status **Pending Developer Release** → `1.0` page → **Release This Version**. Live in the store within ~24 h.
- [ ] `git tag v1.0 && git push --tags`.

---

## Screenshots

### iPhone

App Store Connect slot **iPhone 6.9" Display** takes `1320 × 2868`; **6.5"** takes `1284 × 2778`. Upload the 6.9" set; 6.5" is optional.

Ready — eight simulator shots in Demo mode (iPhone 18 Pro, iOS 27, 2026-10-02), upload in filename order:

- `docs/release/screenshots/6.9/*.jpg` — 1320 × 2868
- `docs/release/screenshots/6.5/*.jpg` — 1284 × 2778

1. `01-world` — World: 7 cities on the shared hour strip, cursor at now
2. `02-sleep` — Sleep ring: tonight's bedtime and wake on whole cycles
3. `03-nap` — Nap alarm: a nap in progress, alarm and cycle-end options
4. `04-what-did` — What did: today's timeline, tags, history
5. `05-jet-lag` — Jet lag planner: sleep profile and upcoming trips
6. `06-lunar` — Lunar: today's lunar date, converter, events
7. `07-countdown` — Countdowns: days as the hero
8. `08-more` — More: the tool list

Retake (simulator, launch arguments compiled only with the `SCREENSHOTS` flag, never in `make release`):

```
xcodebuild -scheme EveryTime -destination 'id=<sim UDID>' -derivedDataPath build \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) SCREENSHOTS' build
xcrun simctl install <UDID> build/Build/Products/Debug-iphonesimulator/EveryTime.app
xcrun simctl status_bar <UDID> override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl launch <UDID> com.solomonxie.everytime -demo YES -screen sleep   # -nap 20 for 03
xcrun simctl io <UDID> screenshot ~/Desktop/shots/02-sleep.png
make screenshots SHOTS=~/Desktop/shots
```

`-screen`: `world`, `sleep`, `whatDid`, `jetLag`, `lunar`, `countdown`, `more` (any `AppTool` raw value; unpinned ones open from More). Outputs overwrite `docs/release/screenshots/6.9` and `6.5`. Drag them into the slots.

### Apple Watch

Required because the build contains a Watch app. Slot sizes (one set is enough; App Store Connect scales it):

| Watch | Pixels |
|---|---|
| Ultra 3 (49 mm) | 422 × 514 |
| Ultra / Ultra 2 (49 mm) | 410 × 502 |
| Series 10 / 11 (46 mm) | 416 × 496 |
| Series 7–9 (45 mm) | 396 × 484 |

Must be captured on the paired Apple Watch (no watchOS simulator shots; none in the repo yet):

1. iPhone → Watch app → General → **Enable Screenshots** on.
2. Install the TestFlight or `make device` build; open Every Time on the Watch after the iPhone app has run once (it sends the snapshot).
3. Press the side button + Digital Crown together per shot. They land in the iPhone's Photos at the watch's native size — upload as-is, no resizing.
4. Shots: **World times**, **Upcoming countdowns**, **Sleep now wake times** (1–3 is fine).
5. App Store Connect → `1.0` page → **Apple Watch** tab under Previews and Screenshots → drop them in.

### Widgets

No separate slot. Optional: one iPhone shot of the Home Screen with the World clock and Countdown widgets as a later screenshot.

App Preview video: skip for 1.0.

---

## App Store Connect pages

### `iOS App → 1.0 Prepare for Submission`

| Field | Value |
|---|---|
| Previews and Screenshots | [Screenshots](#screenshots) (iPhone + Apple Watch) |
| Promotional Text | below |
| Description | below |
| Keywords | below |
| Support URL | `https://github.com/solomonxie/every-time/issues` |
| Marketing URL | leave blank |
| Version | `1.0` |
| Copyright | `2026 Solomon Xie` |
| Routing App Coverage File | leave blank |
| Build | the uploaded build (step 11) |
| App Review → Sign-In Required | Off |
| App Review → Contact First / Last Name | TODO |
| App Review → Phone | TODO (with country code, e.g. `+1 …`) |
| App Review → Email | TODO |
| App Review → Notes | below |
| App Review → Attachment | none |
| Version Release | **Manually release this version** |

Promotional Text (154/170, no price wording — Guideline 2.3.7):

```
World clocks, sleep cycles, nap alarms, jet lag plans, the lunar calendar, countdowns and timers in one app. No account; your data stays on your iPhone.
```

Description:

```
Every Time puts everything about time in one free iPhone app — the time in other cities, when to sleep, when to wake, what you did with your day, and how long until the next thing that matters.

No account. No ads. No server holding your data.

WORLD
• Every city's time on one shared, scrollable hour strip, a week back to a week ahead
• Drag the cursor to see every city at that instant
• Overlapping work hours listed, so meetings land at sane times
• Add a city, or a zone by name: PST, CET, UTC+8, Asia/Shanghai

SLEEP
• Pick when to wake and get bedtimes on whole sleep cycles — or pick bedtime and get wake times
• Nap planner: the best nap length now and its effect on tonight
• Alarm that rings even in silent mode, with a backup
• While asleep: cycles so far and the next good moment to get up
• Coffee cutoff, energy and sleep debt at a glance
• Works with Apple Health: add past nights and learn your own cycle length from Apple Watch sleep stages (optional, read-only)

WHAT DID
• A day log on a drag-through timeline — mark a moment, tag the stretch
• Today's totals, 7-day averages and your typical bed and wake times

JET LAG PLANNER
• Per-trip plan of light, sleep and caffeine timing to shift your body clock before you fly

LUNAR
• Today's Chinese lunar date and a converter
• Lunar birthdays and festivals with their next Gregorian date, optionally added to your Calendar

COUNTDOWNS AND EVENTS
• Count down to any moment, with fireworks, sound and a notification at zero
• Important events: time since, next anniversary, yearly reminder
• On this day: events, births and holidays for any date, from Wikipedia

TIMERS AND TOOLS
• Stopwatch, interview, rehearsal and coding-practice timers, full-screen sideways clock
• Work timer with breaks, daily history and CSV export
• Unix timestamp, timestamp converter, cron expression parser

WIDGETS AND APPLE WATCH
• World clock and next-countdown widgets, including the Lock Screen
• Apple Watch app: world times, upcoming countdowns, sleep-now wake times

YOUR DATA
• Everything stays on your iPhone
• Optional automatic backup to your own iCloud Drive, visible in the Files app
• Local backup copies and file export

Free, with no ads, no analytics and no sign-up.
```

Keywords (97/100 — "world", "clock", "sleep" omitted, the name already indexes them):

```
timezone,meeting,planner,nap,alarm,cycle,bedtime,jetlag,lunar,countdown,stopwatch,timer,unix,wake
```

App Review Notes (also the Guideline 2.1 answers Apple asked to keep here):

```
No account or login. The app opens straight into the World clock. For sample data on every screen: More tab → Demo mode (a separate store; real data untouched; it does not read Health).

PURPOSE AND AUDIENCE
Every Time is a set of time tools for anyone who works across time zones, travels, or wants to sleep and wake at better times: a world clock and meeting planner, a sleep-cycle and nap planner with an alarm, a day log, a jet lag planner, the Chinese lunar calendar, countdowns, timers, and small developer time tools. It replaces several single-purpose apps with one free app that keeps data on the device.

HOW TO USE THE MAIN FEATURES (no setup needed)
- World tab: cities and their hour strips; drag to compare; Add City.
- Sleep tab: tonight's bed and wake plan; tap a row to set the alarm, or pick a nap length to start a nap. The alarm rings at the end.
- What did tab: tap Mark (or the timeline) to log a moment; tag the range.
- Lunar tab: today's lunar date, converter, Add event.
- More tab: every other tool (Jet lag planner, Countdown, Important events, On this day, timers, Unix/cron tools), Demo mode and Settings (iCloud Drive backup, backup list).
- Widgets: World clock and Countdown. Apple Watch app: world times, countdowns, sleep-now wake times.

HEALTHKIT
Read-only access to Sleep Analysis, requested only when the user taps "Add nights from Health" on the Sleep page. Used on the device to list past nights and estimate the user's sleep-cycle length from Apple Watch sleep stages. Nothing is written to Health. Health data is not sent off the device, not used for advertising, not shared, and not stored in iCloud (it is excluded from the iCloud Drive backup).

ALARMS AND BACKGROUND AUDIO
The audio background mode exists only for the user-started nap/sleep alarm, an audible alarm feature.
- iOS 26 and later: the alarm uses AlarmKit; no background audio is used (unless the user declines AlarmKit permission, then the fallback below applies).
- iOS 18–25 (no AlarmKit): a local notification cannot ring through the silent switch, so while a nap alarm is set the app plays the alarm sound muted in a loop to stay running in the background, then raises the volume at the set time. It starts only when the user starts a nap or sets an alarm, the screen says to leave the app open, and it stops as soon as the alarm is stopped or cancelled. No audio plays at any other time.
- A time-sensitive local notification (Time Sensitive entitlement) is scheduled as a backup in case the app is closed.
To test: Sleep tab → pick a nap length (or tap a wake time) → lock the phone → the alarm rings at the set time → Stop.

OTHER PERMISSIONS
- Calendar: full access to pick an existing event as an "important event"; write-only access to add lunar events the user creates.
- Notifications: local reminders for countdowns, events, lunar dates, wind-down, jet lag steps and alarms.

EXTERNAL SERVICES
- Wikipedia REST API (en.wikipedia.org), only when the On this day tool is opened: the request contains the chosen month and day. Content shown with "From Wikipedia · CC BY-SA 4.0" attribution; links open in Safari.
- Apple iCloud Drive, only if the user turns on backup (off by default).
No analytics, advertising, crash reporting, authentication or payment services. We run no server.

REGIONAL DIFFERENCES
The app works the same in every region and is in English. The lunar calendar is the Chinese lunar calendar, available to everyone.

REGULATION
Every Time is a personal planning tool. Sleep and jet lag suggestions are general timing guidance, not medical advice or a medical device, and the app says so. It handles no money, payments or regulated data.

All data is stored on the device. We operate no server and receive no user data.
```

What's New: not shown for a first version. From 1.1 on, write it here.

### `General → App Information`

| Field | Value |
|---|---|
| Name | `Every Time: World Clock, Sleep` |
| Subtitle (29/30) | `Time zones, naps, lunar dates` |
| Category — Primary | Utilities |
| Category — Secondary | Health & Fitness |
| Content Rights | **Yes**, it contains third-party content, and I have the rights — Wikipedia text under CC BY-SA 4.0, attributed in the app |
| Age Rating | **Edit** → answer below → accept the computed rating |
| License Agreement | Apple standard EULA (default) |
| Privacy Policy URL | `https://github.com/solomonxie/every-time/blob/master/docs/release/privacy-policy.md` |

Age rating questionnaire — every answer:

| Section | Answer |
|---|---|
| Parental controls / age assurance | No |
| Unrestricted web access | No (Wikipedia links open in Safari) |
| User-generated content | No |
| Messaging and chat | No |
| Advertising | No |
| Violence, sexual content, profanity, horror | None |
| Mature or suggestive themes | None (On this day lists historical events as plain text) |
| Alcohol, tobacco, drugs | None |
| Medical or treatment information | None (melatonin timing only, no dose; "not medical advice, ask a doctor or pharmacist") |
| Health or wellness topics | **Yes** (sleep, naps, caffeine timing) |
| Gambling, simulated gambling, contests, loot boxes | None / No |
| Made for Kids | No |

Regional (Korea, China Mainland, Vietnam) — leave unset.
**Digital Services Act** trader status: **Not a trader** (free, no monetization) — if App Store Connect blocks EU availability without it, answer this in Business → Compliance.

### `App Store → Trust & Safety → App Privacy`

| Field | Value |
|---|---|
| Privacy Policy URL | same as above |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |

Then **Publish**. Label shows "Data Not Collected".

Why it's true: Health, Calendar and app data are processed only on the device; iCloud Drive backup goes to the user's own account; the Wikipedia request carries only a date. Re-check before each submission:

```
grep -rniE "analytics|firebase|sentry|amplitude|mixpanel|posthog|bugsnag|URLSession" --include='*.swift' EveryTime EveryTimeWatch EveryTimeWidget Glance
```

Only expected hit: `URLSession` in `Features/OnThisDay/OnThisDay.swift`.

### `App Store → Trust & Safety → App Accessibility`

Skip for 1.0 rather than over-claim.

### `App Store → Monetization → Pricing and Availability`

| Field | Value |
|---|---|
| Base Country or Region | United States (USD) |
| Price | **Free** ($0.00) |
| Availability | All countries or regions **except China mainland** |
| Tax Category | App Store software (default) |
| iPhone and iPad Apps on Apple Silicon Macs | **Off** for 1.0 (HealthKit, alarms, Watch untested on Mac) |
| Apple Vision Pro | Off |

China mainland needs an ICP filing number for apps that use the network, and Wikipedia is blocked there. Add it later with an ICP filing (and a `STORE=cn` build that hides On this day, if wanted).

### Not needed for 1.0

In-App Purchases, Subscriptions, In-App Events, Custom Product Pages, Product Page Optimization, Promo Codes, Game Center, Featuring Nominations, Ratings and Reviews, History.

---

## Export compliance

No page for it in App Store Connect — nothing to fill in. `ITSAppUsesNonExemptEncryption = false`
in `Info.plist` (set in `project.yml`) answers it at upload (HTTPS/TLS to Wikipedia, SHA-256 hashing of backups for change detection only → exempt).
Verify: TestFlight → the build is **not** marked "Missing Compliance".
Only if it is: **Manage** → **None of the algorithms mentioned above**.

---

## 简体中文 localization

Skipped: the app UI is English only (no `zh` strings). Add a Chinese listing once the app ships `zh`.
