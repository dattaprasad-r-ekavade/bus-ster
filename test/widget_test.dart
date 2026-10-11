import 'dart:io';
import 'dart:math' as math;

import 'package:busster/game/depot_game.dart';
import 'package:busster/game/game_audio.dart';
import 'package:busster/game/game_model.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:busster/game/game_progress.dart';
import 'package:busster/game/game_settings.dart';
import 'package:busster/game/rewarded_hint_ads.dart';
import 'package:busster/game/route_symbol.dart';
import 'package:busster/main.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<LevelSpec> levels;

  setUpAll(() async {
    levels = LevelBundleCodec.decode(
      await File('assets/levels/levels.json').readAsString(),
    );
  });

  testWidgets('restores the saved depot and move history', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BussterApp(
        levelList: levels,
        initialProgress: GameProgress(
          currentLevelId: 'depot-02',
          dispatches: ['coral'],
          completedLevelIds: ['depot-01'],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('DEPOT 02'), findsOneWidget);
    expect(find.textContaining('1 MOVES'), findsOneWidget);
    expect(find.textContaining('Progress restored'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause overlay resumes the depot', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BussterApp(levelList: levels));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PAUSED'), findsNothing);
    expect(find.byTooltip('Pause game'), findsOneWidget);
  });

  testWidgets('stuck feedback offers undo as well as retry', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = levels.first;
    final trap = LevelSpec(
      id: 'one-bay-trap',
      title: base.title,
      width: base.width,
      height: base.height,
      exit: base.exit,
      roads: base.roads,
      buses: base.buses,
      passengers: base.passengers,
      bayCount: 1,
    );
    await tester.pumpWidget(BussterApp(levelList: [trap]));
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester
        .widget<GameWidget<DepotGame>>(find.byType(GameWidget<DepotGame>))
        .game!;

    game.session.dispatch('blue');
    await tester.pump();

    expect(game.session.state.status, GameStatus.stuck);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      find.text('No clear route remains. Undo a dispatch or retry the depot.'),
      findsOneWidget,
    );
    expect(find.text('UNDO'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pump();

    expect(game.session.state.status, GameStatus.playing);
    expect(find.text('TRY AGAIN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed depot shows clear feedback and next action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BussterApp(levelList: levels));
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester
        .widget<GameWidget<DepotGame>>(find.byType(GameWidget<DepotGame>))
        .game!;
    game.session
      ..dispatch('blue')
      ..dispatch('coral')
      ..dispatch('mint');
    await tester.pump();

    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    expect(find.text('NEXT DEPOT'), findsOneWidget);
    expect(find.textContaining('Depot clear!'), findsOneWidget);

    await tester.tap(find.text('NEXT DEPOT'));
    await tester.pump();

    expect(find.textContaining('DEPOT 02'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings load, save, and update reduced motion live', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryGameSettingsStore(
      const GameSettings(
        hapticsEnabled: false,
        soundEnabled: true,
        reduceMotion: true,
      ),
    );
    await tester.pumpWidget(
      BussterApp(levelList: levels, settingsStore: store),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester
        .widget<GameWidget<DepotGame>>(find.byType(GameWidget<DepotGame>))
        .game!;
    expect(game.reduceMotion, isTrue);

    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('haptics-setting')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('reduce-motion-setting')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('sound-setting')))
          .value,
      isTrue,
    );

    await tester.tap(find.text('Reduce motion'));
    await tester.pump();
    expect(game.reduceMotion, isFalse);
    await tester.tap(find.text('Haptics'));
    await tester.pump();
    await tester.tap(find.text('Sound effects'));
    await tester.pump();
    expect(store.value.hapticsEnabled, isTrue);
    expect(store.value.soundEnabled, isFalse);
    expect(store.value.reduceMotion, isFalse);
    expect(store.saveCount, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful dispatch plays its original sound cue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _RecordingGameAudio();
    await tester.pumpWidget(BussterApp(levelList: levels, audio: audio));
    await tester.pump(const Duration(milliseconds: 100));

    final board = find.byType(GameWidget<DepotGame>);
    final game = tester.widget<GameWidget<DepotGame>>(board).game!;
    await _tapBus(tester, board, game, 'blue');

    expect(audio.played, [GameAudioCue.dispatch]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved sound-off setting prevents dispatch playback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _RecordingGameAudio();
    final store = _MemoryGameSettingsStore(
      const GameSettings(soundEnabled: false),
    );
    await tester.pumpWidget(
      BussterApp(levelList: levels, settingsStore: store, audio: audio),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final board = find.byType(GameWidget<DepotGame>);
    final game = tester.widget<GameWidget<DepotGame>>(board).game!;
    await _tapBus(tester, board, game, 'blue');

    expect(audio.played, isEmpty);
    expect(store.value.hapticsEnabled, isTrue);
    expect(store.value.soundEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rewarded Route Tip requires opt-in and confirmed reward', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final postIntroLevels = [...levels, _copyLevelAs(levels.last, 'depot-11')];
    final ads = _FakeRewardedHintAds(rewardEarned: true);
    await tester.pumpWidget(
      BussterApp(
        levelList: postIntroLevels,
        initialProgress: GameProgress(
          currentLevelId: 'depot-11',
          dispatches: const [],
          completedLevelIds: levels.map((level) => level.id),
          earnedHints: 0,
        ),
        rewardedHintAds: ads,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('ROUTE TIP · 0'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('WATCH AD'), findsOneWidget);
    expect(ads.showCount, 0);

    await tester.tap(find.text('WATCH AD'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(ads.showCount, 1);
    expect(find.textContaining('Route tip (0 left)'), findsOneWidget);
    expect(
      tester
          .widget<GameWidget<DepotGame>>(find.byType(GameWidget<DepotGame>))
          .game!
          .session
          .earnedHints,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing a rewarded ad without reward grants no hint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final postIntroLevels = [...levels, _copyLevelAs(levels.last, 'depot-11')];
    final ads = _FakeRewardedHintAds(rewardEarned: false);
    await tester.pumpWidget(
      BussterApp(
        levelList: postIntroLevels,
        initialProgress: GameProgress(
          currentLevelId: 'depot-11',
          dispatches: const [],
          completedLevelIds: levels.map((level) => level.id),
          earnedHints: 0,
        ),
        rewardedHintAds: ads,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('ROUTE TIP · 0'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('WATCH AD'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(ads.showCount, 1);
    expect(find.textContaining('No Route Tip was earned'), findsOneWidget);
    expect(
      tester
          .widget<GameWidget<DepotGame>>(find.byType(GameWidget<DepotGame>))
          .game!
          .session
          .earnedHints,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the first ten depots never show an ad offer', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ads = _FakeRewardedHintAds(rewardEarned: true);
    await tester.pumpWidget(
      BussterApp(
        levelList: levels,
        initialProgress: GameProgress(
          currentLevelId: 'depot-01',
          dispatches: const [],
          earnedHints: 0,
        ),
        rewardedHintAds: ads,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('ROUTE TIP · 0'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('WATCH AD'), findsNothing);
    expect(ads.showCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'depot picker exposes unlocked depots and keeps locked ones shut',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        BussterApp(
          levelList: levels,
          initialProgress: GameProgress(
            currentLevelId: 'depot-02',
            dispatches: ['coral'],
            completedLevelIds: ['depot-01'],
            earnedHints: 4,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('ROUTE TIP · 4'), findsOneWidget);
      await tester.tap(find.byTooltip('Select depot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SELECT DEPOT'), findsOneWidget);
      expect(find.textContaining('DEPOT 03 · Queue order'), findsOneWidget);

      await tester.tap(find.textContaining('DEPOT 03 · Queue order'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SELECT DEPOT'), findsOneWidget);

      await tester.tap(find.textContaining('DEPOT 01 · One clear route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Leave this depot?'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.textContaining('DEPOT 02'), findsOneWidget);

      await tester.tap(find.byTooltip('Select depot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.textContaining('DEPOT 01 · One clear route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('SWITCH DEPOT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('DEPOT 01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps gameplay controls visible on a compact phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BussterApp(levelList: levels));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BUS-STER'), findsOneWidget);
    expect(find.byTooltip('Pause game'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);
    expect(find.text('HINT 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps core controls readable with enlarged system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await tester.pumpWidget(BussterApp(levelList: levels));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Pause game'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);
    expect(find.text('HINT 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the first depot and rider queue', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BussterApp(levelList: levels));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BUS-STER'), findsOneWidget);
    expect(find.textContaining('DEPOT 01'), findsOneWidget);
    expect(find.text('NEXT RIDERS'), findsOneWidget);
    expect(find.text('FIFO QUEUE'), findsOneWidget);
    expect(find.byType(RouteSymbol), findsNWidgets(6));
    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel('Next rider, Coral'), findsOneWidget);
      expect(find.bySemanticsLabel('Queued rider, Mint'), findsNWidgets(2));
    } finally {
      semantics.dispose();
    }
    expect(find.textContaining('ROUTE TIP · 3'), findsOneWidget);
    expect(find.textContaining('Tap a bus with a clear road'), findsOneWidget);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('How to play'), findsOneWidget);
    expect(find.textContaining('Riders board from the front'), findsOneWidget);

    await tester.tap(find.text('GOT IT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Debug overlay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('DEBUG · depot-01'), findsOneWidget);
    expect(find.textContaining('blue: 2 tiles'), findsOneWidget);
    expect(find.textContaining('Solver: blue → coral → mint'), findsOneWidget);
  });
}

class _MemoryGameSettingsStore implements GameSettingsStore {
  _MemoryGameSettingsStore(this.value);

  GameSettings value;
  int saveCount = 0;

  @override
  Future<GameSettings> load() async => value;

  @override
  Future<void> save(GameSettings settings) async {
    value = settings;
    saveCount++;
  }
}

class _RecordingGameAudio implements GameAudio {
  final List<GameAudioCue> played = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> play(GameAudioCue cue) async {
    played.add(cue);
  }

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeRewardedHintAds extends RewardedHintAds {
  _FakeRewardedHintAds({required this.rewardEarned});

  final bool rewardEarned;
  bool ready = true;
  int showCount = 0;

  @override
  bool get isEnabled => true;

  @override
  bool get isReady => ready;

  @override
  bool get isLoading => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> showRewardedHint({required VoidCallback onRewardEarned}) async {
    showCount++;
    ready = false;
    notifyListeners();
    if (rewardEarned) onRewardEarned();
    return rewardEarned;
  }

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<void> retryLoad() async {}

  @override
  Future<void> close() async => super.dispose();
}

LevelSpec _copyLevelAs(LevelSpec source, String id) => LevelSpec(
  id: id,
  title: source.title,
  localizedTitles: source.localizedTitles,
  width: source.width,
  height: source.height,
  exit: source.exit,
  roads: source.roads,
  buses: source.buses,
  passengers: source.passengers,
  tutorialPrompt: source.tutorialPrompt,
  localizedTutorialPrompts: source.localizedTutorialPrompts,
  bayCount: source.bayCount,
  mechanicTags: source.mechanicTags,
  difficultyBand: source.difficultyBand,
  seed: source.seed,
);

Future<void> _tapBus(
  WidgetTester tester,
  Finder board,
  DepotGame game,
  String busId,
) async {
  final boardRect = tester.getRect(board);
  final component = game.firstChild<DepotBoard>()!;
  final level = game.session.level;
  final cellSize = math.min(
    (component.size.x - 28) / level.width,
    (component.size.y - 56) / level.height,
  );
  final position = level.busById(busId).position;
  final target = Offset(
    boardRect.left +
        (component.size.x - cellSize * level.width) / 2 +
        (position.x + 0.5) * cellSize,
    boardRect.top +
        (component.size.y - cellSize * level.height) / 2 +
        12 +
        (position.y + 0.5) * cellSize,
  );
  await tester.tapAt(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
