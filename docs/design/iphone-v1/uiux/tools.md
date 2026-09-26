# Tools

```
Tools
─────────────────────────────────────────────────
Unix timestamp                                 ›
Timestamp converter                            ›
Cron expression parser                         ›
```

## Unix timestamp (live)
```
      1758790867                        ← ticks every second, tap to copy
Seconds        1758790867           📋
Milliseconds   1758790867123        📋
ISO 8601       2026-09-25T09:41:07Z  📋
```

## Timestamp converter
```
TIMESTAMP → DATE
┌─────────────────────────────────┐
│ 1758790867▌                     │  ← s or ms auto-detected (>1e11 = ms)
└─────────────────────────────────┘
Local          Thu, Sep 25, 2026, 2:41:07 AM
UTC            Thu, Sep 25, 2026, 9:41:07 AM
Relative       5 minutes ago
DATE → TIMESTAMP
Date           [Sep 25, 2026  2:41 AM]
Seconds        1758790860           📋
```
```
invalid   ⚠ Not a number
```

## Cron parser
```
┌─────────────────────────────────┐
│ */15 9-17 * * 1-5▌              │
└─────────────────────────────────┘
Every 15 minutes, 9–17h, Mon–Fri       ← plain-English summary
NEXT RUNS
Fri, Sep 26  9:00 AM
Fri, Sep 26  9:15 AM
… (5 rows)
EXAMPLES   @hourly · 0 0 * * * · 30 8 * * 1  ← tap fills field
```
```
invalid   ⚠ Expected 5 fields, got 4
```
Supports: `* , - /`, numbers, JAN–DEC, SUN–SAT, @hourly/@daily/@weekly/@monthly/@yearly.
