# Bus-ster privacy policy draft

> **Internal draft, not ready to publish.** This records the current prototype's data flows as inspected on 11 October 2026. It is not legal advice or a release policy. Recheck the final APK/AAB, all SDK behavior, Android backup settings, launch markets, and publisher details before using it publicly.

## App and publisher details to complete

- App: Bus-ster
- Android application ID: `com.busster.busster` (prototype ID; confirm before first Play release)
- Publisher/legal entity: **[add publisher name]**
- Privacy and support contact: **[add a monitored email or public support URL]**
- Effective date: **[set for release]**

## Current prototype data handling

Bus-ster does not have an account system or a game server. The gameplay code does not send game data to an analytics, advertising, crash-reporting, or billing provider. The telemetry adapter is a no-op. A local release-profile APK built on 11 October 2026 targets API 36, has minimum API 24, and its merged manifest does not declare `INTERNET`; the debug manifest does include that development permission. The release-profile APK is signed with the repository's debug key and is not a store-ready artifact. Recheck the final signed AAB and all merged SDK permissions before publication.

The game stores the following in the app's private storage:

- Progress: current depot ID, the sequence of bus dispatches needed to resume an attempt, completed depot IDs, and the Route Tip balance.
- Preferences: whether haptics are enabled and whether reduced motion is enabled.

Progress is stored in the app-support directory. Preferences use Android's app-scoped shared-preferences storage. The game does not ask for a name, email address, contacts, location, photos, or other personal information.

The app does not operate a server, so it has no server-side gameplay records to delete. A player can remove local app data through Android Settings or uninstall the app. Android's device backup and restore behavior has not been verified for the current storage paths; confirm whether system backup can transfer these files before making a public statement about where data is stored or how long it persists.

## Third-party services in this build

The runtime dependencies are Flutter, Flame, `path_provider`, and `shared_preferences`. They are used for rendering/input and app-local storage. Firebase, Google Mobile Ads, Play Billing, and a crash-reporting SDK are not integrated in this prototype. Recheck the complete dependency and merged-manifest inventory in the release artifact before publication.

## Required release updates

This draft must be rewritten if analytics, crash reporting, ads, billing, remote configuration, cloud saves, account features, or other data-processing services are added. Review the data practices of every SDK, implement required disclosures and consent, and keep the privacy policy and Play Console Data safety answers consistent. Google Play requires an accurate privacy policy and Data safety disclosure; its policy also specifies publisher/contact details and access from both Play Console and the app. See [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311) and [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469).

Before release, replace every bracketed field, choose a stable public non-PDF URL, add an in-app route to the policy, verify Android backup behavior, and have the final text reviewed for the actual publisher and launch regions.
