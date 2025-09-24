# Release Notes

## [Unreleased]

### Fixed
- Prevented the app from resolving `NSUbiquitousKeyValueStore` unless cloud sync preferences are enabled and the account is available, which eliminates the `SyncedDefaults Code=8888` console spam on launch. To confirm the fix:
  1. Launch Offshore Budgeting on a device or simulator where *Enable Cloud Sync* and all related toggles remain off (the default state).
  2. Inspect the Xcode console during startup and ensure no `SyncedDefaults Code=8888` messages appear.
- Stopped Budget Details from regressing to the "Loading…" placeholder after the budget has already been fetched. To validate:
  1. Open any budget, then quickly toggle *Settings → Cloud Sync → Enable Cloud Sync* off and on (or otherwise trigger multiple `.dataStoreDidChange` notifications in quick succession).
  2. Return to the budget and observe that the list stays populated without flashing the loading placeholder.
