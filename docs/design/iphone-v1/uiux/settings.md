# Settings

Pushed from More → Settings (last section). Backups only, for now.
Patterns: `uiux` backup-restore + platform-cloud-drive.

## Default (iCloud on, ready)

```
‹ More            Settings
BACKUP ⓘ
☁ iCloud Drive                               ●──
  Files → iCloud Drive → Every Time · 4 min ago
Outlives deleting the app.

THIS IPHONE ⓘ
📱 Daily copies
   Files → On My iPhone → Every Time · last 7 days

⬆ Export backup…
⬇ Import backup…
```

## iCloud row states

Blocked state replaces the location line; switch disabled.

```
☁ iCloud Drive                 ──○   off (ready)
  Files → iCloud Drive → Every Time

☁ iCloud Drive                 ●──   just flipped on → backs up at once
  Files → iCloud Drive → Every Time · backing up…

☁ iCloud Drive                 ●──   on, data still empty
  Files → iCloud Drive → Every Time · nothing to back up yet

☁ iCloud Drive                 ●──   write failed (real error only)
  Last backup failed: <reason>

☁ iCloud Drive                 ──○   notEntitled — no instruction
  This build of the app isn't signed for iCloud

☁ iCloud Drive                 ──○   driveOff — the only state with directions
  iCloud Drive is off on this device
  Settings → your name → iCloud → iCloud Drive → turn on   ← accent

☁ iCloud Drive                 ──○   notReady
  Setting up your iCloud folder — try again shortly
```

Re-checked on every foreground. Auto path never alerts; signed-out is silent.

## ⓘ popovers

```
BACKUP ⓘ →  A copy of your cities, lunar and "since" dates, timer settings
            and LeetCode history, as one small .zip. Saved once a day when
            something changed; iCloud Drive keeps the latest 10. It's a
            backup, not sync between devices. Reinstall the app and your
            data comes back from iCloud by itself.

THIS IPHONE ⓘ →  A copy is also saved here once a day, and before every
                 import. They go when the app does, so they're for undoing
                 a mistake, not for a lost phone: import one to roll back.
```

## Export

```
Export backup… → system save sheet, name 20260925-daily-every-time.zip
nothing stored yet → footer: Nothing to export yet.
```

## Import

```
Import backup… → file picker (.zip)
        │
        ▼
┌──────────────────────────────────────────────┐
│    Replace your data with this backup?       │
│ 4 cities · 2 lunar events · 12 LeetCode      │
│ sessions · saved Sep 25, 2026                │
│                                              │
│ What's here now is saved to Files → On My    │
│ iPhone → Every Time first.                   │
├──────────────────────────────────────────────┤
│                 Replace!                     │
├──────────────────────────────────────────────┤
│                 Cancel                       │
└──────────────────────────────────────────────┘
Replace → before-import zip → keys replaced → footer:
  Restored 4 cities · 2 lunar events · … .
```

Errors (alert "Can't import this file", OK):

```
Couldn't read that file.
This isn't an Every Time backup.
This backup is from a newer version of Every Time. Update the app, then import it again.
This backup has nothing in it.
```

Before-import copy fails → nothing replaced, footer:
`Couldn't save a copy of the current data first, so nothing was replaced.`

## Fresh install

No UI. First launch with no stored data → newest iCloud archive applied
silently, once; iCloud switch turned on unless already chosen.
