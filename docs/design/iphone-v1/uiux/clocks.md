# Clocks (superseded)

List view replaced by [world.md](world.md). City picker below is still current.

```
Clocks                                  Edit   +
─────────────────────────────────────────────────
Cupertino                          9:41:07 AM   ← device tz pinned, not deletable
Local · Thu, Sep 25
─────────────────────────────────────────────────
New York                           12:41 PM
Today, +3h
─────────────────────────────────────────────────
London                             5:41 PM
Today, +8h
─────────────────────────────────────────────────
Singapore                          12:41 AM
Tomorrow, +15h                           ← day word vs device day
─────────────────────────────────────────────────
Kathmandu                          10:26 PM
Today, +12h 45m                          ← non-hour offsets shown fully
```

Reached from: launch (tab 1)

## States
```
empty   only the Local row + hint "Tap + to add a city"
edit    ⊖ on each city row, ≡ reorder handle; swipe-left → Delete!
```

## City picker (sheet, shared with Meetings)

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
( Cancel )          Add City
┌───────────────────────────────────────────────┐
│ 🔍 Search city or time zone▌                  │   ← autofocus
└───────────────────────────────────────────────┘
Tokyo                          Asia/Tokyo  +9
Tokyo … (all matches from TimeZone.knownTimeZoneIdentifiers,
         city = last path component, "_" → " ")
Already added cities                         ✓   ← not selectable
```
```
no match   No time zones match "Tokio"
```

| Target | Action | Result |
|---|---|---|
| row | tap | add, dismiss sheet |
| city row | swipe left | Delete |
