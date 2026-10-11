# Bus-ster privacy policy draft

> **Internal draft, not ready to publish, and not legal advice.** It records the data handling of the current build as inspected on 11 October 2026 (branch `rebuild/bus-jam-core`). Before any public use: recheck the final signed AAB's merged manifest and every SDK, verify Android backup/restore on real devices, fill in publisher details, and have the text reviewed for the actual publisher and launch regions.

## App and publisher details to complete

- App: Bus-ster (working title; name check pending)
- Android application ID: `com.busster.busster` (confirm before first Play release)
- Publisher / legal entity: **[add publisher name]**
- Privacy and support contact: **[add a monitored email or public support URL]**
- Effective date: **[set for release]**

## Data inventory (current build)

Bus-ster is an offline puzzle game. It has no account system, no game server, no ads, no in-app purchases, and no analytics or crash-reporting SDK. The main Android manifest requests no permissions; `INTERNET` appears only in the debug and profile manifests that Flutter uses for development tooling. Gameplay events go to a no-op adapter and are discarded (see [ANALYTICS_EVENT_SCHEMA.md](ANALYTICS_EVENT_SCHEMA.md)).

The game asks for no name, email, contacts, location, photos or other personal information.

It stores only the following, in the app's private storage on the device:

| Data | Where | Contents |
| --- | --- | --- |
| Progress | `files/busster-progress.json`, plus a last-good copy `busster-progress.json.bak` (a short-lived `.tmp` exists only during a save) | Schema version, highest unlocked level index, list of completed level ids. |
| Settings | `files/datastore/FlutterSharedPreferences.preferences_pb` (SharedPreferences, DataStore backend) | Three on/off switches: sound, haptics (vibration), reduced motion. |

Nothing else is persisted: the in-level state, undo history and hints live in memory only.

## Android backup and device transfer

The manifest enables Android backup (`allowBackup="true"`) with explicit allow-lists in `res/xml/backup_rules.xml` (Android 11 and below) and `res/xml/data_extraction_rules.xml` (Android 12+). Only three files are included, for both cloud backup and device-to-device transfer: `busster-progress.json`, `busster-progress.json.bak`, and the DataStore preferences file. Whether a backup or transfer happens depends on the device, Android version and the user's own settings; the copy is held by the user's backup provider (for example Google), and Bus-ster neither receives nor controls it. Restore has not yet been tested on a physical device.

## Deletion

There is no server-side data. A player can delete everything by clearing the app's data in Android Settings or uninstalling the app. Any separately retained system backup is managed through the user's device / Google account backup settings.

## Third-party components

Runtime dependencies: Flutter SDK, `flutter_localizations` / `intl`, `path_provider` (locates the private files directory), `shared_preferences` (settings), and `audioplayers` 6.7.1 (plays four bundled local WAV files). None of these is used to send data off the device in this build. Re-inspect the merged release manifest for permissions contributed by plugins before answering Play's Data safety form.

## Audience

Owner direction: adults / general audience. This is not yet a Play Console age-group declaration. If any child age group is ever selected, the Families policy and applicable regional law must be reviewed first.

## Required release updates

Rewrite this draft before adding analytics, crash reporting, ads, purchases, remote configuration, cloud saves, accounts or any other data-processing service. Keep the public policy, the in-app link and the Play Data safety answers consistent with the build actually shipped. Google Play requires an accurate privacy policy linked from both the store listing and the app; see the [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311) and [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469).

Before release: replace every bracketed field, choose a stable public non-PDF URL, add an in-app link to the policy, verify backup and restore on supported Android versions, and revisit the backup allow-list whenever the storage implementation changes.
