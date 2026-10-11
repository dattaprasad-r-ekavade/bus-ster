# Bus-ster privacy policy draft

> **Internal draft, not ready to publish.** This records the current prototype's data flows as inspected on 11 October 2026. It is not legal advice or a release policy. Recheck the final signed AAB, all SDK behavior, Android backup and restore on supported devices, launch markets, and publisher details before using it publicly.

## App and publisher details to complete

- App: Bus-ster
- Android application ID: `com.busster.busster` (prototype ID; confirm before first Play release)
- Publisher/legal entity: **[add publisher name]**
- Privacy and support contact: **[add a monitored email or public support URL]**
- Effective date: **[set for release]**

## Current prototype data handling

Bus-ster does not have an account system or a game server. The gameplay code does not send game data to an analytics, advertising, crash-reporting, or billing provider. The telemetry adapter is a no-op. A local release-profile APK built on 11 October 2026 targets API 36, has minimum API 24, and its merged manifest does not declare `INTERNET`; the debug manifest does include that development permission. The release-profile APK is signed with the repository's debug key and is not a store-ready artifact. Recheck the final signed AAB and all merged SDK permissions before publication.

The game stores the following in the app's private storage:

- Progress: current depot ID, the sequence of bus dispatches needed to resume an attempt, completed depot IDs, and the Route Tip balance. The validated current save and its last-good recovery copy are stored in Android's private files directory.
- Preferences: whether haptics are enabled and whether reduced motion is enabled. The current Android `SharedPreferencesAsync` backend uses DataStore Preferences in the app's private `files/datastore/FlutterSharedPreferences.preferences_pb` file.

The game does not ask for a name, email address, contacts, location, photos, or other personal information. It does not operate an account or game server.

The Android manifest explicitly enables system backup and limits it to the current progress file, its last-good recovery copy, and the DataStore preferences file. Android Auto Backup can save eligible app data to the user's configured backup transport, such as Google backup, and Android supports direct device-to-device transfer. Whether backup or transfer runs depends on the device, Android version, and the user's settings. Bus-ster does not receive or control the backup copy. Temporary progress writes and damaged-save quarantine files are not included by these allow-list rules.

The game has no server-side gameplay records to delete. A player can remove local app data through Android Settings or uninstall the app; any separately retained system backup is managed by the Android backup provider and the user's device/account settings. Physical-device backup and restore testing remains open because the project currently has no test phones.

## Third-party services in this build

The runtime dependencies are Flutter, Flame, `path_provider`, and `shared_preferences`. They are used for rendering/input and app-local storage. Firebase, Google Mobile Ads, Play Billing, and a crash-reporting SDK are not integrated in this prototype. Recheck the complete dependency and merged-manifest inventory in the release artifact before publication.

## Required release updates

This draft must be rewritten if analytics, crash reporting, ads, billing, remote configuration, cloud saves, account features, or other data-processing services are added. Review the data practices of every SDK, implement required disclosures and consent, and keep the privacy policy and Play Console Data safety answers consistent. Google Play requires an accurate privacy policy and Data safety disclosure; its policy also specifies publisher/contact details and access from both Play Console and the app. See [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311) and [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469).

Before release, replace every bracketed field, choose a stable public non-PDF URL, add an in-app route to the policy, verify backup and restore on supported Android versions, and have the final text reviewed for the actual publisher and launch regions. Revisit the backup allow-list whenever the progress or settings storage implementation changes.
