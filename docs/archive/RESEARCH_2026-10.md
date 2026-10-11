# Bus-ster desk research (October 2026)

> **Historical desk research, not current status.** Extracted on 11 October 2026 from the pre-rebuild `GAME_PLAN.md` (see git history before the rebuild for the full original). It reflects Google Play listings, policy pages and package docs as read on that date. Nothing here was verified by hands-on play, player sessions or legal review. Store policies, SDK versions and fees change: recheck every source before acting on it. Current status lives in [GAME_PLAN.md](../../GAME_PLAN.md) and [REBUILD_PLAN.md](../REBUILD_PLAN.md).

## 1. Market scan

Snapshot from Google Play listings reviewed on 11 October 2026. Install and review counts are store signals only; they do not reveal revenue, retention, acquisition cost or profitability. Review excerpts are self-selected anecdotes, not a survey.

| Game | Public listing signals | Takeaway for Bus-ster |
| --- | --- | --- |
| [Bus Fever Party!](https://play.google.com/store/apps/details?id=gridplus.busjam.carpuzzle) | 10M+ downloads, ads and in-app purchases. Describes clearing a parking jam, moving vehicles through tight spaces, matching passengers, and boosters. Screenshots show a crowded vehicle lot, direction marks, passenger area and boarding spaces. Reviews praise distinguishable colours; complaints mention early difficulty, ad load and expensive VIP parking. | The owner's reference for feel. Category interest is visible; precise rules and revenue are unverified. |
| [Bus Jam: Traffic Escape](https://play.google.com/store/apps/details?id=com.ashlabs.busjam) | Promotes solver-verified levels, offline play, colour-blind-friendly colours, themed worlds, optional reward ads, interstitials after level 15, and a no-ads purchase. | Solver validation, offline play, colour accessibility and optional ads are table stakes, not differentiation. |
| [Bus Go! Car Traffic Jam](https://play.google.com/store/apps/details?id=bus.go.car.jam.traffic) | 5M+ downloads, ~63K reviews, ads and IAP; bus/car traffic puzzles, passenger matching, boosters. A visible review alleges levels become pay/help dependent. | Scale exists, no public revenue proof. Do not design difficulty around booster use. |
| [Bus Away: Traffic Jam](https://play.google.com/store/apps/details?id=com.fc.bus.away.traffic.jam) | 1M+ downloads, ~32K reviews, ads and IAP; traffic, passenger pickup, parking, power-ups. | The basic loop is widely repeated; store art, title, layouts, copy and feel need a distinct identity. |

**Revenue evidence:** public listings do not disclose competitor revenue. Validate retention, ad tolerance, conversion and country-level net revenue in a small test before buying installs.

**Working-title check:** Play lists [Busster](https://play.google.com/store/apps/details?id=com.colixsystems.android.busster), a Swedish business workflow app. That is a near-name collision and discoverability risk even though the category differs. "Bus-ster" stays provisional until a proper trademark, domain and Play title search; this listing search is not legal clearance.

## 2. Originality and IP

Use the reference for genre direction only. Do not copy its levels, screenshots, UI layout, icon, audio, store copy or name. The [US Copyright Office](https://www.copyright.gov/register/tx-games.html) distinguishes game methods from protected expression, and [Google Play's IP policy](https://support.google.com/googleplay/android-developer/answer/9888072) requires rights to app and listing content. Have the final title and icon checked for confusing similarity before submission.

## 3. Audience

Owner direction (11 October 2026): adults / general audience, worldwide reach as the ambition, no soft-launch countries chosen. This is a product direction, not a Play Console age-group declaration. Select only age groups the finished game and store creative genuinely serve. If children are included, the Families requirements apply (ad SDK eligibility, age screen, data and legal checks). See [target-audience guidance](https://support.google.com/googleplay/android-developer/answer/9867159) and the [Families policy](https://support.google.com/googleplay/android-developer/answer/9893335). Pick first countries only after language, support, ad suitability, privacy/legal and device coverage can be reviewed for them.

## 4. Monetization design notes

Ordered by intended adoption; none of this is implemented.

1. **Primary:** opt-in rewarded video for an extra hint or undo after a fair free allowance. State the reward before the ad, grant it only from the reward callback, prevent duplicate grants, and keep every level solvable without ads.
2. **Secondary:** one permanent "remove forced ads" purchase if interstitials are ever introduced; purchases must restore. Start a soft launch with rewarded ads only.
3. **Only after evidence:** restrained interstitials after a results screen — never during play, at level start, or in the first session; frequency-capped with a kill switch. Google Play [restricts unexpected full-screen ads](https://support.google.com/googleplay/android-developer/answer/9857753).
4. **Avoid initially:** expensive short-lived VIP products, energy timers, deliberately impossible levels, pay-gated bays, subscriptions without continuing value.
5. **Billing:** [Google Play Billing for digital goods](https://support.google.com/googleplay/android-developer/answer/10281818) via Flutter's [in_app_purchase](https://pub.dev/packages/in_app_purchase); verify entitlements, handle pending/cancelled/refunded transactions, acknowledge purchases, use license testers, take localized prices from Play. See current [Billing guidance](https://developer.android.com/google/play/billing).
6. **Ads SDK, if adopted:** official [google_mobile_ads](https://docs.flutter.dev/cookbook/plugins/google-mobile-ads) with Google test IDs in development; UMP consent before any request ([rewarded](https://developers.google.com/admob/flutter/rewarded), [UMP/privacy](https://developers.google.com/admob/flutter/privacy)); publish `app-ads.txt` on a developer-controlled site before full serving. Mediation only after a baseline. The SDK adds network, advertising-ID and Privacy Sandbox permissions to the merged manifest, which must be reflected in Data safety.

**Illustrative unit economics — arithmetic, not a forecast.** Assume 10,000 DAU, 40,000 MAU, 0.6 rewarded impressions/DAU/day at $6 eCPM, 0.25 interstitials at $3 eCPM, 1% of MAU buying $5/month, 20% store/tax/refund deduction. Ads: `10,000 × (0.6×6 + 0.25×3) ÷ 1,000 × 30 = $1,305/month`. IAP: `40,000 × 1% × $5 × 80% = $1,600/month`. Total ≈ $2,905/month before acquisition, tools, content, support and taxes (rewarded-only: $1,080 ads). Geography, fill, consent, retention and ad load change this sharply.

| Operating target (hypothesis) | Why |
| --- | --- |
| Tutorial completion ≥ 80%; first 10 levels without paid help ≥ 70% | The game teaches rather than traps |
| D1 ≥ 35%, D7 ≥ 10%, D30 ≥ 4% in a stable cohort | Internal gates, not claimed industry benchmarks |
| Crash-free users ≥ 99.5%; ANRs trending down; 60 fps on midrange devices | Playable, reviewable product |
| Rewarded opt-in without a fall in D7 | Monetization adds value without harming the game |
| 30-day contribution LTV/CAC ≥ 1.3 before paid acquisition | Avoid buying revenue at a loss |

Metrics to track per cohort and geography once analytics exist: DAU/MAU, sessions/user, level attempts and solve rate, stuck/retry/undo/hint use, D1/D7/D30, ad availability/show/reward, ad ARPDAU, IAP conversion, refunds, net revenue, support themes, install source. Never put personal data in event names or parameters.

## 5. Play release policy checklist (as read October 2026)

- **Target API:** new submissions must target Android 16 / API 36+ under the rule effective 31 August 2026 ([target API policy](https://support.google.com/googleplay/android-developer/answer/11926878)).
- **Signing and bundles:** signed `.aab`, Play App Signing, upload keys outside Git ([App Bundle](https://developer.android.com/guide/app-bundle), [signing](https://developer.android.com/studio/publish/app-signing)).
- **Data safety and privacy policy:** must match actual SDK behaviour ([Data safety](https://support.google.com/googleplay/android-developer/answer/10787469), [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)).
- **Developer verification:** Google states all Play packages must be registered under Android developer verification effective 30 September 2026 ([package registration](https://support.google.com/googleplay/android-developer/answer/16984799)); check whether `com.busster.busster` needs an owner action.
- **Testing requirement:** new personal developer accounts need 12 continuously opted-in testers for 14 days before production access ([testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465)).
- **Families:** review art, wording, gameplay and ad behaviour before selecting any child age group ([Families policy](https://support.google.com/googleplay/android-developer/answer/9893335)).
- Also: content rating, ads declaration, app access, store text/screenshots, support channel, release notes, rollback plan.

## 6. Tooling notes

| Need | Note |
| --- | --- |
| Engine | Flutter's [Casual Games Toolkit](https://docs.flutter.dev/resources/games-toolkit) covers this class of puzzle. Plain widgets + `CustomPainter` proved enough; [Flame](https://docs.flame-engine.org/latest/) was tried and removed. |
| Local state | [`path_provider`](https://pub.dev/packages/path_provider) JSON file for progress; [`shared_preferences`](https://pub.dev/packages/shared_preferences) (`SharedPreferencesAsync`, DataStore backend) for settings only. SQLite only if data outgrows this. |
| Audio | [`audioplayers`](https://pub.dev/packages/audioplayers) 6.7.1 — the Flutter 3.41.6 / Dart 3.11.4 toolchain cannot use the 6.8.1 SDK constraint; recheck when upgrading. |
| Observability (future) | [Firebase Analytics](https://firebase.google.com/docs/analytics/flutter/get-started), [Crashlytics](https://firebase.google.com/docs/crashlytics/flutter/get-started), [Remote Config](https://firebase.google.com/docs/remote-config/flutter/get-started), each behind an adapter so the game works offline. Never make a puzzle unsolvable via remote values. |
| Localization | [Flutter internationalization](https://docs.flutter.dev/ui/internationalization) (`gen-l10n`, ARB). Add a locale only with reviewed translations and QA. |
| Social (post-launch) | [Play Games Services](https://developer.android.com/games/pgs/start) v2 only; [v1 is being retired](https://developer.android.com/games/pgs/deprecation). |
| Device QA profiles (proposed) | (1) API 24 minimum for install/start; (2) low-cost Android 13 / API 33, 3–4 GB RAM, 720p; (3) current Android 16 / API 36, 6–8 GB RAM, 1080p+. Emulators cover none of the low-end physical risks. |
| Contrast | [WCAG 2.2 non-text contrast](https://www.w3.org/WAI/WCAG22/understanding/non-text-contrast.html) 3:1 for rule-critical shapes. |

**Development MCPs (never runtime dependencies):** the official [Dart/Flutter MCP](https://dart.googlesource.com/ai/+/HEAD/pkgs/dart_mcp_server/README.md) (`dart mcp-server`, configured in `.vscode/mcp.json`); [Firebase MCP](https://firebase.google.com/docs/ai-assistance/mcp-server) only once a Firebase dev project exists; [GitHub MCP](https://github.com/github/github-mcp-server) optional; [Blender MCP](https://www.blender.org/lab/mcp-server/) only for prerendered art, in a disposable workspace. Do not adopt unverified third-party MCPs with Play Console publishing or payment access.
