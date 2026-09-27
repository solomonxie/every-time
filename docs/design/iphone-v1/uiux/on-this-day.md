# On this day

Wikipedia's "On this day" for any date. Dates group in More ([more.md](more.md)). Visual language: [visual.md](visual.md).
Code: `EveryTime/Features/OnThisDay/`. First network feature.

```
‹ More          On this day       Today   ← toolbar item only when not today
( ‹ )        [ Sep 26, 2026 ]       ( › ) ← soft prev/next day, compact picker
[Selected|Events|Births|Deaths|Holidays]
SELECTED  20
╭───────────────────────────────────╮
│ 2024  2 years ago               ↗ │   ← year Font.clock 28 tint; BC for < 0
│ Hurricane Helene makes landfall…  │
│ Hurricane Helene                  │   ← first linked page, secondary
╰───────────────────────────────────╯
╭───────────────────────────────────╮
│ Canadian Martyrs                ↗ │   ← holidays: no year, text as title
╰───────────────────────────────────╯
        From Wikipedia · CC BY-SA 4.0
```
- Tap row → first page in Safari; long-press → all linked pages.
- Pull to refresh (forces a fetch).

## Data
- `GET https://en.wikipedia.org/api/rest_v1/feed/onthisday/all/MM/DD`, no key, `User-Agent: EveryTime/<version> (iOS; repo URL)`.
- Cache: last copy per MM/DD in memory + `Caches/OnThisDay/MM-DD.json`; shown instantly, refetched after 24 h. Not backed up.

## States
- Loading (no cache): `Asking Wikipedia…` spinner.
- Failed, no cache: `Couldn't load this day` · wifi.slash · reason (offline / timed out / unexpected) · ( Try again ).
- Failed, cached: content + `Offline — saved 3 days ago`.
- Empty feed: `Nothing listed`; empty section: `Nothing under births for this day.`
