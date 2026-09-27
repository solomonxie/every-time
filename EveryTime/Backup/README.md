# Backup

All user data is small Codable JSON in UserDefaults (`@Stored`). Backed up = every key with prefix
`world.` `calendar.` `timers.` `sleep.` `tools.` `app.` (`BackupSnapshot.keyPrefixes`) — new keys travel automatically.

## Tiers

| Tier | Where | When | Retention |
|---|---|---|---|
| 1. This iPhone (`LocalBackups`) | app Documents → Files → On My iPhone → Every Time | app-background, max hourly, only if changed; before every import/restore | `BackupRetention` |
| 2. iCloud Drive (`CloudDrive`, `AutoBackup`) | `iCloud.com.example.everytime/Documents` → Files → iCloud Drive → Every Time | one switch; flip-on at once; foreground/background, max hourly, only if changed; "Back up now" | `BackupRetention` |

- Retention (`BackupRetention`): all from the last 48 h, newest per day for 14 days, newest per month for a year, always the newest 3; foreign files never touched.
- Every save is its own timestamped file — nothing overwrites an earlier backup.
- Writes verified by reading back before pruning; iCloud writes/deletes go through `NSFileCoordinator`.
- Change gate = SHA-256 of the snapshot entries, recorded only after a verified write. Empty snapshots never written.
- `CloudDriveStatus`: entitlement (embedded.mobileprovision) checked before `ubiquityIdentityToken`.
- `FirstRunRestore`: no user content (non-empty lists/objects; launch-time settings like the selected tab don't count) + flag unset → newest readable iCloud archive applied silently, once.
- Browse: Settings → iCloud Drive / Copies on this iPhone → list with per-backup counts → detail (counts vs now, restore, share).
- Restore/import (`BackupRestore`): current data saved to tier 1 first; aborts if that fails. Notifications, widget and watch refreshed after.

## Known limits

- Two iPhones on one Apple ID write to the same folder; the newest file wins on reinstall.
- Changes made less than an hour after the last backup wait for the next foreground/background.

## Format

```
20260925140233-auto-every-time.zip            automatic (tier 1 + 2)
20260925140233-before-import-every-time.zip   before an import/restore (tier 1)
20260925-daily-every-time.zip                 export, and older automatic copies
└── snapshot.json   {version, createdAt, appVersion, entries: {key: <embedded JSON>}}
```

Store-only zip (`ZipArchive`). Decoding is hand-written; newer versions and empty snapshots are refused.

## Restore

Replaces the backed-up keys (absent keys revert to defaults); `@AppStorage` views refresh themselves.
Deviation from "restore creates a new dataset": there is no database to swap, so the before-import zip is the undo.

## Signing

iCloud needs a paid team and the container registered in Xcode; free-team builds show "isn't signed for iCloud".
