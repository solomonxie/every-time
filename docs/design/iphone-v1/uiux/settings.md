# Settings

Inline sections at the bottom of More (no separate page). Backups only,
for now. Patterns: `uiux` backup-restore + platform-cloud-drive.

## Default (iCloud on, ready)

```
More (scrolled to bottom)
…
TAB BAR  3 of 4                         ← more.md
…
BACKUP ⓘ
☁ iCloud Drive                            On  ›   ← opens the list
  Files → iCloud Drive → Every Time · 4 min ago
Outlives deleting the app.

THIS IPHONE ⓘ
📱 Copies on this iPhone                      ›
   Files → On My iPhone → Every Time
```

## Backups list (pushed)

```
iCloud Drive
╭───────────────────────────────────────╮
│ Back up to iCloud Drive          ●──  │   ← the switch lives here (cloud only)
│ ⟳ Back up now                         │   ← disabled when up to date
╰───────────────────────────────────────╯
Up to date with this iPhone.
12 BACKUPS
│ Sep 26, 2026 at 2:02 PM        2h ago │
│ Automatic · 3 KB                      │
│ 🌐 4  📅 2  ⭐ 3  ⏳ 1  </> 12          │   ← counts per kind, from the archive
│ …  Still in iCloud — pull to retry    │   ← not downloaded in time
Files → … Saved within an hour of a change… (retention)
```

Detail: Saved · Kind · Size · App version · File; CONTENTS rows (count, orange "now N" when this iPhone differs), Settings count; "Restore this backup…" (confirm; current data saved to This iPhone first) · Share file….

```

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
BACKUP ⓘ →  Everything added and set, as one small .zip. Saved within an hour
            of a change, each its own file; kept a year, thinning with age.
            Tap iCloud Drive to see contents or restore. Backup, not sync.
            Reinstall → data comes back from iCloud by itself.

THIS IPHONE ⓘ →  Also saved here, and before every import/restore. Goes with
                 the app: for undoing a mistake, not a lost phone.
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
