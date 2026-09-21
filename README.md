# Every Time

> 🚧 Work in progress — skeleton only, not yet functional.

Everything about time, in one free iPhone app. A world clock keeps a list of
cities across timezones side by side. A set of purpose-built timers covers a
LeetCode timer that keeps a persistent history of past practice sessions, an
interview timer, a "reversal timer", and a plain stopwatch. A meeting-time
lookup shows overlapping working hours across several timezones at once, so
scheduling across a distributed team doesn't need a separate tool. A sleep
calculator suggests bedtimes for a target wake-up time based on ~90-minute
REM sleep cycles instead of a flat "8 hours" rule, in the spirit of apps like
Timeshifter. A waiting/queue-time lookup rounds things out with a place to
check public wait-time data — theme parks, DMV-style offices, and similar.

The same time tools are also available from the wrist via a companion Apple
Watch app, and a home-screen widget surfaces a glanceable clock without
opening the app.

## Setup

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```
xcodegen generate && open EveryTime.xcodeproj
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
