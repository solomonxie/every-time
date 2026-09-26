# More

Always the last tab. Every tool one tap away, then the tab bar editor and
Settings, all inline on one scrolling page. Plain background, card rows.

```
More                                         ← screenTitle
MAIN
🌐 World        📌                          ›   ← 📌 = pinned to tab bar
☾ Sleep         📌                          ›
📅 Lunar        📌                          ›
TIMERS
⏱ Stopwatch                         03:12   ›   ← live, only once started
🎤 Interview                        45:00   ›   ← live remaining
↺ Rehearsal                        +00:42   ›   ← overtime shows +
</> LeetCode                    12 sessions ›
⌛ Countdown                                ›   ← countdown.md
DATES
☆ Important events                          ›
⌛ Wait times                               ›
DEVELOPER
# Unix timestamp                            ›
⇄ Timestamp converter                       ›
🗓 Cron parser                              ›

TAB BAR  3 of 4
🌐 World                          ⊖   ≡      ← hold + drag to reorder
☾ Sleep                           ⊖   ≡
📅 Lunar                          ⊖   ≡
⊕ Add a tool                                 ← menu of unpinned tools, by group
Up to 4, shown before More. Hold and drag to reorder.

BACKUP ⓘ … THIS IPHONE ⓘ … Export / Import  ← settings.md
```

## Tab bar rules

- Tab bar = 1–4 pinned tools, then More. Default: World · Sleep · Lunar.
- Any tool can be pinned: rows' swipe/long-press → Pin to / Unpin from tab bar.
- 4 pinned → Add disabled, footer: `Up to 4. Remove one to add another.`
- 1 pinned → its ⊖ disabled (min 1).
- Unpinning the tab you're on is only possible from More, so selection stays on More.

```
4 pinned                          1 pinned
TAB BAR  4 of 4                   TAB BAR  1 of 4
…                                 🌐 World            ⊖(dim)  ≡
⊕ Add a tool          (dim)       ⊕ Add a tool
Up to 4. Remove one to add another.
```

## Shared timers

Timer state lives app-wide (`TimerStore`), so a pinned Interview tab and
More → Interview are the same run; countdown alarms fire from any tab.

Stored: `app.tabs` (pins, backed up), `app.tab` (selected tab).
