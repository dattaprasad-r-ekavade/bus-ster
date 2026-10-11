# Bus-ster privacy policy draft

> **Internal draft, not ready to publish.** This records the current prototype's data flows as inspected on 11 October 2026. It is not legal advice or a release policy. Recheck the final signed AAB, all SDK behavior, Android backup and restore on supported devices, launch markets, and publisher details before using it publicly.

## App and publisher details to complete

- App: Bus-ster
- Android application ID: `com.busster.busster` (prototype ID; confirm before first Play release)
- Publisher/legal entity: **[add publisher name]**
- Privacy and support contact: **[add a monitored email or public support URL]**
- Effective date: **[set for release]**

## Current prototype data handling

Bus-ster does not have an account system or a game server. Gameplay events use a no-op telemetry adapter and are not sent or saved. The Google Mobile Ads SDK and UMP are now runtime dependencies, but the release build gate is off unless explicit production IDs and a build flag are supplied. In the default release configuration, the Dart ad controller does not request consent information, initialize Mobile Ads, or load ads. The Google Mobile Ads startup provider is removed so it cannot initialize the SDK before the UMP consent check.

The SDK is still packaged in Android release artifacts. The merged release manifest adds `INTERNET`, `ACCESS_NETWORK_STATE`, `com.google.android.gms.permission.AD_ID`, and Android Privacy Sandbox ad permissions (`ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_TOPICS`). The APK/AAB currently uses the debug signing key and is a validation artifact, not a store-ready build. Recheck the final signed AAB and every SDK's runtime behavior before answering Play's ads and Data safety forms. If production ads are enabled, UMP consent requests and ad requests become network data flows and must be described accurately in the public policy and disclosures.

The game stores the following in the app's private storage:

- Progress: current depot ID, the sequence of bus dispatches needed to resume an attempt, completed depot IDs, and the Route Tip balance. The validated current save and its last-good recovery copy are stored in Android's private files directory.
- Preferences: whether haptics, sound effects, and reduced motion are enabled. The current Android `SharedPreferencesAsync` backend uses DataStore Preferences in the app's private `files/datastore/FlutterSharedPreferences.preferences_pb` file.

The game does not ask for a name, email address, contacts, location, photos, or other personal information. It does not operate an account or game server.

The Android manifest explicitly enables system backup and limits it to the current progress file, its last-good recovery copy, and the DataStore preferences file. Android Auto Backup can save eligible app data to the user's configured backup transport, such as Google backup, and Android supports direct device-to-device transfer. Whether backup or transfer runs depends on the device, Android version, and the user's settings. Bus-ster does not receive or control the backup copy. Temporary progress writes and damaged-save quarantine files are not included by these allow-list rules.

The game has no server-side gameplay records to delete. A player can remove local app data through Android Settings or uninstall the app; any separately retained system backup is managed by the Android backup provider and the user's device/account settings. Physical-device backup and restore testing remains open because the project currently has no test phones.

## Third-party services in this build

The runtime dependencies are Flutter, Flame, `path_provider`, `shared_preferences`, `audioplayers`, and `google_mobile_ads` 9.1.0. The audio plugin plays four bundled local WAV effects. Firebase Analytics, Crashlytics, Play Billing, and a game server are not configured. Debug test ads are available only with `--dart-define=BUSSTER_ENABLE_TEST_ADS=true`, using Google's official sample app and rewarded unit IDs. Production ads need the publisher's app ID and unit ID, an explicit release build flag, configured UMP messages, an approved audience/content setup, and a policy review; none is configured. The owner has confirmed adults/general audience and worldwide reach as the product direction. This does not settle Play Console age-group selections: those must match the finished game's features and store creative. If children are included in the target audience, the project must review Families policy, eligible ads SDK use, mixed-audience age screening, and applicable regional law. Worldwide is a long-term ambition; first soft-launch countries, localization, support coverage, content rating, and legal/privacy review remain open.

## Required release updates

This draft must be rewritten if analytics, crash reporting, ads, billing, remote configuration, cloud saves, account features, or other data-processing services are added. Review the data practices of every SDK, implement required disclosures and consent, and keep the privacy policy and Play Console Data safety answers consistent. Google Play requires an accurate privacy policy and Data safety disclosure; its policy also specifies publisher/contact details and access from both Play Console and the app. See [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311) and [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469).

Before release, replace every bracketed field, choose a stable public non-PDF URL, add an in-app route to the policy, verify backup and restore on supported Android versions, and have the final text reviewed for the actual publisher and launch regions. Revisit the backup allow-list whenever the progress or settings storage implementation changes.
