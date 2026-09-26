# Backup

All user data is small Codable JSON in UserDefaults (`@Stored`). Backed up = every key with prefix
`world.` `calendar.` `timers.` `sleep.` `tools.` (`BackupSnapshot.keyPrefixes`) — new keys travel automatically.

## Tiers

| Tier | Where | When | Retention |
|---|---|---|---|
| 1. This iPhone (`LocalBackups`) | app Documents → Files → On My iPhone → Every Time | app-background, max daily, only if changed; before every import | 7 days by age |
| 2. iCloud Drive (`CloudDrive`, `AutoBackup`) | `iCloud.com.solomonxie.everytime/Documents` → Files → iCloud Drive → Every Time | one switch; flip-on at once; foreground/background, daily, only if changed | latest 10 |

- Tier 1 is rollback only: never a destination, never offered to restore from in-app.
- Change gate = SHA-256 of the snapshot entries, recorded only after a successful write.
- `CloudDriveStatus`: entitlement (embedded.mobileprovision) checked before `ubiquityIdentityToken`.
- `FirstRunRestore`: no backed-up keys + flag unset → newest iCloud archive applied silently, once.
- Manual: Settings → Export / Import (picker only).

## Format

```
20260925-daily-every-time.zip                 daily (tier 1 + 2, export)
20260925140233-before-import-every-time.zip   before an import (tier 1)
└── snapshot.json   {version, createdAt, appVersion, entries: {key: <embedded JSON>}}
```

Store-only zip (`ZipArchive`). Decoding is hand-written; newer versions and empty snapshots are refused.

## Restore

Replaces the backed-up keys (absent keys revert to defaults); `@AppStorage` views refresh themselves.
Deviation from "restore creates a new dataset": there is no database to swap, so the before-import zip is the undo.

## Signing

iCloud needs a paid team and the container registered in Xcode; free-team builds show "isn't signed for iCloud".
