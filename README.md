# Every Time

> 🚧 Work in progress — iPhone app functional (Wait times is sample data); widget and watch are stubs. Docs: `docs/design/iphone-v1/`.

Everything about time, in one free iPhone app.

- **World** — World Time Buddy–style planner: city column pinned left, hour
  strips share one horizontal scroll across a week, a center cursor shows every
  city's time at that instant, work-hour overlaps listed as jump targets.
- **Sleep** — bedtimes for a wake time (or wake times for "bed now") from
  ~90-minute sleep cycles.
- **Lunar** — today's Chinese lunar date, a converter, and lunar events
  (once / monthly / yearly) with their next Gregorian date, optionally added
  to the iPhone Calendar.
- **More** — flat list of the rest: stopwatch, interview timer, reversal
  timer, LeetCode timer with session history, "how long since…", wait times,
  Unix timestamp, timestamp converter, cron parser. Timers open a full-screen
  sideways clock. Settings: iCloud Drive and local zip backups
  (`EveryTime/Backup/README.md`).

Planned: a companion Apple Watch app and a home-screen clock widget.

## Setup

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```
xcodegen generate && open EveryTime.xcodeproj
```

Install on a device (team ID from env, never committed). iCloud backup needs a paid team with
container `iCloud.com.solomonxie.everytime` registered (Xcode → Signing & Capabilities → iCloud):

```
xcodebuild -scheme EveryTime -destination id=$DEVICE_UDID -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=$TEAM_ID build
xcrun devicectl device install app --device $DEVICE_UDID <DerivedData>/Debug-iphoneos/EveryTime.app
```

## Watch target note

The watch app is built as a modern single-target app (`type: application`,
`platform: watchOS`, `WKApplication = YES`) embedded in the iOS app, rather
than XcodeGen's `application.watchapp2` product type. On Xcode 26+,
`application.watchapp2` emits a stale "Embed Watch Content" copy phase that
collides with Xcode's own product install step and fails the build with
"Multiple commands produce ...EveryTimeWatch.app/EveryTimeWatch" — a known
XcodeGen/Xcode incompatibility (yonaskolb/XcodeGen#1613). The plain
`application` product type sidesteps it and is itself how modern Xcode
project templates set up single-target watch apps.

## Screenshots

| World | Sleep | Lunar | More |
|---|---|---|---|
| <img src="docs/screenshots/world.png" width="200"> | <img src="docs/screenshots/sleep.png" width="200"> | <img src="docs/screenshots/lunar.png" width="200"> | <img src="docs/screenshots/more.png" width="200"> |
