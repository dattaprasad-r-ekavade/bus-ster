import 'package:busster/game/rewarded_hint_ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('environment configuration keeps ads disabled by default', () {
    expect(RewardedHintAdsConfig.fromEnvironment().enabled, isFalse);
  });

  test('does not load an ad when UMP does not permit requests', () async {
    final gateway = _FakeRewardedHintAdsGateway(canRequestAds: false);
    final ads = AdMobRewardedHintAds(
      config: RewardedHintAdsConfig.test,
      gateway: gateway,
    );
    addTearDown(ads.close);

    await ads.initialize();
    await ads.retryLoad();

    expect(gateway.consentUpdateCount, 1);
    expect(gateway.loadCount, 0);
    expect(ads.isReady, isFalse);
  });

  test('retries a failed load once, then offers only a loaded ad', () async {
    final gateway = _FakeRewardedHintAdsGateway(loadResults: [false, true]);
    final ads = AdMobRewardedHintAds(
      config: RewardedHintAdsConfig.test,
      gateway: gateway,
    );
    addTearDown(ads.close);

    await ads.initialize();

    expect(gateway.loadCount, 2);
    expect(gateway.loadedUnitIds, [
      RewardedHintAdsConfig.testRewardedAdUnitId,
      RewardedHintAdsConfig.testRewardedAdUnitId,
    ]);
    expect(ads.isReady, isTrue);
  });

  test('only an SDK reward callback result can grant the hint', () async {
    final gateway = _FakeRewardedHintAdsGateway(rewardEarned: false);
    final ads = AdMobRewardedHintAds(
      config: RewardedHintAdsConfig.test,
      gateway: gateway,
    );
    addTearDown(ads.close);

    await ads.initialize();
    var callbackCount = 0;
    expect(
      await ads.showRewardedHint(onRewardEarned: () => callbackCount++),
      isFalse,
    );

    expect(gateway.showCount, 1);
    expect(callbackCount, 0);
    expect(ads.isReady, isFalse);
  });

  test('privacy options refresh permission before loading an ad', () async {
    final gateway = _FakeRewardedHintAdsGateway(
      privacyOptionsRequired: true,
      canRequestAds: false,
    );
    final ads = AdMobRewardedHintAds(
      config: RewardedHintAdsConfig.test,
      gateway: gateway,
    );
    addTearDown(ads.close);

    await ads.initialize();
    expect(ads.privacyOptionsRequired, isTrue);
    expect(gateway.loadCount, 0);

    gateway.canRequestAds = true;
    await ads.showPrivacyOptions();

    expect(gateway.privacyOptionsCount, 1);
    expect(gateway.loadCount, 1);
    expect(ads.isReady, isTrue);
  });
}

class _FakeRewardedHintAdsGateway implements RewardedHintAdsGateway {
  _FakeRewardedHintAdsGateway({
    this.canRequestAds = true,
    this.privacyOptionsRequired = false,
    this.rewardEarned = true,
    List<bool> loadResults = const [true],
  }) : loadResults = [...loadResults];

  bool canRequestAds;
  bool privacyOptionsRequired;
  final bool rewardEarned;
  final List<bool> loadResults;
  int consentUpdateCount = 0;
  int privacyOptionsCount = 0;
  int loadCount = 0;
  int showCount = 0;
  final List<String> loadedUnitIds = [];

  @override
  Future<bool> updateConsentAndInitialize() async {
    consentUpdateCount++;
    return canRequestAds;
  }

  @override
  Future<bool> getPrivacyOptionsRequired() async => privacyOptionsRequired;

  @override
  Future<bool> showPrivacyOptions() async {
    privacyOptionsCount++;
    return canRequestAds;
  }

  @override
  Future<bool> loadRewardedAd(String adUnitId) async {
    loadedUnitIds.add(adUnitId);
    final index = loadCount++;
    return index < loadResults.length ? loadResults[index] : false;
  }

  @override
  Future<bool> showRewardedAd({
    required void Function() onUserEarnedReward,
  }) async {
    showCount++;
    if (rewardEarned) onUserEarnedReward();
    return rewardEarned;
  }

  @override
  Future<void> dispose() async {}
}
