# Visual language

Modern, minimal, intuitive. One accent, lots of air, numbers as the hero.
Components: `EveryTime/Shared/Theme.swift`.

```
Screen                                    ← plain background (no grouped grey)
World                                     ← large rounded bold title
                                          ← 20pt side padding everywhere
SECTION LABEL                        ⓘ    ← tiny caps, tracked, secondary
╭───────────────────────────────────╮
│ Card: 5% primary fill, radius 22  │    ← surfaces, not bordered boxes
│ 10:45 PM    ← clock font: thin rounded tabular
╰───────────────────────────────────╯
[[            Primary action          ]]  ← full-width capsule, bottom only
( Now )  ( Edit )                         ← soft capsules for secondary
```

Rules
- **Numbers are the hero**: times/durations in `Font.clock` (light, rounded, tabular); labels small and secondary.
- **One accent** (blue from the icon, `AccentColor`); state colors only for meaning — orange warn/overtime, red done/destructive, green best lap.
- **Cards over lists** for dashboards (World, Lunar today, timers); plain `List` only for editable collections and forms, with `.scrollContentBackground(.hidden)`.
- **Primary action at the bottom**, one per screen, `PrimaryButtonStyle`; secondary actions are `SoftButtonStyle` capsules; no toolbar clutter (max one toolbar item).
- **Icons**: SF Symbols, monochrome `.secondary` in rows, `.tint` only when it's the thing to tap.
- **Motion**: `.snappy` springs, `.contentTransition(.numericText())` for changing numbers, `.sensoryFeedback` on start/stop/save.
- **Density**: 44pt min targets, 12pt rhythm, no dividers where spacing separates.
- **Dark mode first-class**: fills are `primary.opacity`, never hard greys.
