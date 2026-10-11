import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UI-facing boundary for the optional, consent-gated Route Tip ad.
abstract class RewardedHintAds extends ChangeNotifier {
  bool get isEnabled;
  bool get isReady;
  bool get isLoading;
  bool get privacyOptionsRequired;

  Future<void> initialize();

  /// Returns true only after the ad SDK reports that the reward was earned.
  Future<bool> showRewardedHint({required VoidCallback onRewardEarned});

  Future<void> showPrivacyOptions();

  Future<void> retryLoad();

  Future<void> close();
}

abstract interface class RewardedHintAdsGateway {
  Future<bool> updateConsentAndInitialize();
  Future<bool> getPrivacyOptionsRequired();
  Future<bool> showPrivacyOptions();
  Future<bool> loadRewardedAd(String adUnitId);
  Future<bool> showRewardedAd({required VoidCallback onUserEarnedReward});
  Future<void> dispose();
}

class RewardedHintAdsConfig {
  const RewardedHintAdsConfig._({
    required this.enabled,
    required this.adUnitId,
  });

  static const testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  static const disabled = RewardedHintAdsConfig._(enabled: false, adUnitId: '');

  static const test = RewardedHintAdsConfig._(
    enabled: true,
    adUnitId: testRewardedAdUnitId,
  );

  final bool enabled;
  final String adUnitId;

  /// Test ads require an explicit debug define. Production remains off unless
  /// both IDs and an explicit enable define are supplied at build time.
  factory RewardedHintAdsConfig.fromEnvironment() {
    const testAdsEnabled = bool.fromEnvironment('BUSSTER_ENABLE_TEST_ADS');
    if (kDebugMode && testAdsEnabled) return test;

    const productionAdsEnabled = bool.fromEnvironment(
      'BUSSTER_ENABLE_PRODUCTION_ADS',
    );
    const appId = String.fromEnvironment('BUSSTER_ADMOB_APP_ID');
    const rewardedAdUnitId = String.fromEnvironment(
      'BUSSTER_REWARDED_AD_UNIT_ID',
    );
    final validAppId = RegExp(r'^ca-app-pub-\d{16}~\d{10}$').hasMatch(appId);
    final validAdUnitId = RegExp(
      r'^ca-app-pub-\d{16}/\d+$',
    ).hasMatch(rewardedAdUnitId);
    if (!kReleaseMode ||
        !productionAdsEnabled ||
        !validAppId ||
        !validAdUnitId) {
      return disabled;
    }
    return RewardedHintAdsConfig._(enabled: true, adUnitId: rewardedAdUnitId);
  }
}

class NoopRewardedHintAds extends RewardedHintAds {
  @override
  bool get isEnabled => false;

  @override
  bool get isReady => false;

  @override
  bool get isLoading => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> showRewardedHint({required VoidCallback onRewardEarned}) async =>
      false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<void> retryLoad() async {}

  @override
  Future<void> close() async {}
}

class AdMobRewardedHintAds extends RewardedHintAds {
  AdMobRewardedHintAds({
    required RewardedHintAdsConfig config,
    required RewardedHintAdsGateway gateway,
  }) : _config = config,
       _gateway = gateway;

  factory AdMobRewardedHintAds.fromEnvironment() => AdMobRewardedHintAds(
    config: RewardedHintAdsConfig.fromEnvironment(),
    gateway: GoogleMobileAdsGateway(),
  );

  static const _maxLoadAttempts = 2;
  static const _retryDelay = Duration(seconds: 1);

  final RewardedHintAdsConfig _config;
  final RewardedHintAdsGateway _gateway;
  bool _initialized = false;
  bool _initializing = false;
  bool _loadingAd = false;
  bool _showingAd = false;
  bool _ready = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _closed = false;
  DateTime? _lastLoadAttempt;

  @override
  bool get isEnabled => _config.enabled;

  @override
  bool get isReady => _ready;

  @override
  bool get isLoading => _initializing || _loadingAd;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> initialize() async {
    if (!isEnabled || _closed || _initialized || _initializing) return;
    _initializing = true;
    notifyListeners();
    try {
      _initialized = true;
      _canRequestAds = await _gateway.updateConsentAndInitialize();
      _privacyOptionsRequired = await _gateway.getPrivacyOptionsRequired();
      if (_canRequestAds) await _loadAd();
    } on Object {
      _canRequestAds = false;
      _ready = false;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  @override
  Future<bool> showRewardedHint({required VoidCallback onRewardEarned}) async {
    if (!isEnabled || _closed || !_ready || _showingAd) return false;
    _ready = false;
    _showingAd = true;
    notifyListeners();
    var earnedReward = false;
    try {
      earnedReward = await _gateway.showRewardedAd(
        onUserEarnedReward: onRewardEarned,
      );
      return earnedReward;
    } on Object {
      return false;
    } finally {
      _showingAd = false;
      notifyListeners();
      unawaited(_loadAd());
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (!isEnabled || _closed || !_privacyOptionsRequired || _showingAd) {
      return;
    }
    try {
      final canRequestAds = await _gateway.showPrivacyOptions();
      _canRequestAds = canRequestAds;
      _privacyOptionsRequired = await _gateway.getPrivacyOptionsRequired();
      if (canRequestAds && !_ready) {
        await _loadAd();
      } else if (!canRequestAds) {
        _ready = false;
        await _gateway.dispose();
      }
    } on Object {
      // Privacy choices and the core game remain available if the SDK fails.
    } finally {
      notifyListeners();
    }
  }

  @override
  Future<void> retryLoad() async {
    if (!isEnabled ||
        _closed ||
        !_initialized ||
        !_canRequestAds ||
        _ready ||
        _loadingAd ||
        _showingAd) {
      return;
    }
    final lastAttempt = _lastLoadAttempt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < const Duration(seconds: 10)) {
      return;
    }
    await _loadAd();
  }

  Future<void> _loadAd() async {
    if (_loadingAd ||
        _closed ||
        _ready ||
        !_config.enabled ||
        !_canRequestAds) {
      return;
    }
    _loadingAd = true;
    _lastLoadAttempt = DateTime.now();
    notifyListeners();
    try {
      for (var attempt = 0; attempt < _maxLoadAttempts; attempt++) {
        if (attempt > 0) await Future<void>.delayed(_retryDelay);
        try {
          if (await _gateway.loadRewardedAd(_config.adUnitId)) {
            _ready = true;
            return;
          }
        } on Object {
          // Retry once, then return to the normal ad-free game path.
        }
      }
      _ready = false;
    } finally {
      _loadingAd = false;
      notifyListeners();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _gateway.dispose();
    super.dispose();
  }
}

/// Google UMP and Mobile Ads implementation. No targeting or location data is
/// attached to requests; the game does not request ads before UMP permits it.
class GoogleMobileAdsGateway implements RewardedHintAdsGateway {
  static const _callbackTimeout = Duration(seconds: 20);
  static const _loadTimeout = Duration(seconds: 15);

  RewardedAd? _rewardedAd;

  @override
  Future<bool> updateConsentAndInitialize() async {
    var consentInfoUpdated = false;
    final updateCompleter = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        consentInfoUpdated = true;
        if (!updateCompleter.isCompleted) updateCompleter.complete();
      },
      (FormError error) {
        if (!updateCompleter.isCompleted) updateCompleter.complete();
      },
    );

    try {
      await updateCompleter.future.timeout(_callbackTimeout);
    } on Object {
      // A prior UMP choice may still permit requests when refresh is offline.
    }

    if (consentInfoUpdated) {
      final formCompleter = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (!formCompleter.isCompleted) formCompleter.complete();
      });
      try {
        await formCompleter.future.timeout(_callbackTimeout);
      } on Object {
        // Check canRequestAds below after form load/show errors or timeout.
      }
    }

    var canRequestAds = false;
    try {
      canRequestAds = await ConsentInformation.instance.canRequestAds().timeout(
        _callbackTimeout,
      );
    } on Object {
      canRequestAds = false;
    }
    if (canRequestAds) {
      try {
        await MobileAds.instance.initialize().timeout(_callbackTimeout);
      } on Object {
        return false;
      }
    }
    return canRequestAds;
  }

  @override
  Future<bool> getPrivacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> showPrivacyOptions() async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await completer.future.timeout(_callbackTimeout);
      return await ConsentInformation.instance.canRequestAds().timeout(
        _callbackTimeout,
      );
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> loadRewardedAd(String adUnitId) async {
    await _rewardedAd?.dispose();
    _rewardedAd = null;
    final completer = Completer<RewardedAd>();
    var loadTimedOut = false;
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (loadTimedOut || completer.isCompleted) {
            unawaited(ad.dispose());
          } else {
            completer.complete(ad);
          }
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      ),
    );
    try {
      _rewardedAd = await completer.future.timeout(_loadTimeout);
      return true;
    } on Object {
      loadTimedOut = true;
      return false;
    }
  }

  @override
  Future<bool> showRewardedAd({
    required VoidCallback onUserEarnedReward,
  }) async {
    final ad = _rewardedAd;
    _rewardedAd = null;
    if (ad == null) return false;

    final completer = Completer<bool>();
    var earnedReward = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (closedAd) {
        unawaited(closedAd.dispose());
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        unawaited(failedAd.dispose());
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
    );
    try {
      ad.show(
        onUserEarnedReward: (adWithoutView, rewardItem) {
          if (earnedReward) return;
          earnedReward = true;
          onUserEarnedReward();
        },
      );
      return await completer.future;
    } on Object {
      await ad.dispose();
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
