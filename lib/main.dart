import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game/depot_game.dart';
import 'game/game_audio.dart';
import 'game/game_model.dart';
import 'game/game_palette.dart';
import 'game/game_progress.dart';
import 'game/game_session.dart';
import 'game/rewarded_hint_ads.dart';
import 'game/game_settings.dart';
import 'game/game_telemetry.dart';
import 'game/progress_store.dart';
import 'game/route_symbol.dart';
import 'game/settings_store.dart';
import 'game/parking_jam_screen.dart';
import 'l10n/app_localizations.dart';

enum StorageNotice {
  unavailable,
  unreadable,
  newerVersion,
  resumeFailed,
  saveFailed,
  damaged,
  recoveredBackup,
  damagedBoth,
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BussterApp(levelList: [], useParkingJamPrototype: true));
}

class BussterApp extends StatelessWidget {
  const BussterApp({
    super.key,
    required this.levelList,
    this.progressStore,
    this.initialProgress,
    this.startupWarning,
    this.settingsStore,
    this.telemetry,
    this.audio,
    this.rewardedHintAds,
    this.useParkingJamPrototype = false,
  });

  final List<LevelSpec> levelList;
  final ProgressFileStore? progressStore;
  final GameProgress? initialProgress;
  final StorageNotice? startupWarning;
  final GameSettingsStore? settingsStore;
  final GameTelemetry? telemetry;
  final GameAudio? audio;
  final RewardedHintAds? rewardedHintAds;
  final bool useParkingJamPrototype;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus-ster',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: useParkingJamPrototype
          ? ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF7F4E8),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFF1BE4E),
                brightness: Brightness.light,
                surface: const Color(0xFFFFFCF1),
              ),
              useMaterial3: true,
            )
          : ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF101A2A),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFC857),
                brightness: Brightness.dark,
                surface: const Color(0xFF1B2940),
              ),
              useMaterial3: true,
            ),
      home: useParkingJamPrototype
          ? const ParkingJamScreen()
          : DepotScreen(
              levelList: levelList,
              progressStore: progressStore,
              initialProgress: initialProgress,
              startupWarning: startupWarning,
              settingsStore: settingsStore,
              telemetry: telemetry,
              audio: audio ?? const SilentGameAudio(),
              rewardedHintAds: rewardedHintAds,
            ),
    );
  }
}

class DepotScreen extends StatefulWidget {
  const DepotScreen({
    super.key,
    required this.levelList,
    this.progressStore,
    this.initialProgress,
    this.startupWarning,
    this.settingsStore,
    this.telemetry,
    this.audio,
    this.rewardedHintAds,
  });

  final List<LevelSpec> levelList;
  final ProgressFileStore? progressStore;
  final GameProgress? initialProgress;
  final StorageNotice? startupWarning;
  final GameSettingsStore? settingsStore;
  final GameTelemetry? telemetry;
  final GameAudio? audio;
  final RewardedHintAds? rewardedHintAds;

  @override
  State<DepotScreen> createState() => _DepotScreenState();
}

class _DepotScreenState extends State<DepotScreen> with WidgetsBindingObserver {
  static const _adFreeIntroLevelCount = 10;

  late final GameSession _session;
  late final DepotGame _game;
  late final GameSettingsStore _settingsStore;
  late final GameAudio _audio;
  late final RewardedHintAds _rewardedHintAds;
  GameSettings _settings = GameSettings.defaults;
  int _settingsChanges = 0;
  StorageNotice? _storageNotice;
  String? _lastSavedProgress;
  String? _lastQueuedProgress;
  Future<void> _saveQueue = Future<void>.value();
  bool _rewardedHintFlowInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsStore =
        widget.settingsStore ?? SharedPreferencesGameSettingsStore();
    _audio = widget.audio ?? const SilentGameAudio();
    _rewardedHintAds =
        widget.rewardedHintAds ?? AdMobRewardedHintAds.fromEnvironment();
    _rewardedHintAds.addListener(_onRewardedHintAdsChanged);
    _session = GameSession(
      levelList: widget.levelList,
      telemetry: widget.telemetry ?? const NoopGameTelemetry(),
      logInitialLevelStart: widget.initialProgress == null,
    );
    _game = DepotGame(
      _session,
      onSuccessfulDispatch: _onSuccessfulDispatch,
      reduceMotion: _settings.reduceMotion,
    );
    unawaited(_loadSettings());
    _storageNotice = widget.startupWarning;
    if (widget.initialProgress != null) {
      try {
        _session.restoreProgress(widget.initialProgress!);
        _lastSavedProgress = jsonEncode(_session.progress.toJson());
        _lastQueuedProgress = _lastSavedProgress;
      } on Object {
        _storageNotice = StorageNotice.resumeFailed;
      }
    }
    _session.addListener(_queueProgressSave);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _rewardedHintAds.isEnabled) {
        unawaited(_rewardedHintAds.initialize());
      }
    });
  }

  Future<void> _loadSettings() async {
    final changesBeforeLoad = _settingsChanges;
    try {
      final loaded = await _settingsStore.load();
      if (!mounted || changesBeforeLoad != _settingsChanges) return;
      setState(() => _settings = loaded);
      _game.reduceMotion = loaded.reduceMotion;
      if (loaded.soundEnabled) unawaited(_audio.initialize());
    } on Object {
      // Settings are optional; the game remains playable with defaults.
    }
  }

  Future<void> _updateSettings(GameSettings settings) async {
    if (_settings.soundEnabled && !settings.soundEnabled) {
      unawaited(_audio.stopAll());
    } else if (!_settings.soundEnabled && settings.soundEnabled) {
      unawaited(_audio.initialize());
    }
    _settingsChanges++;
    setState(() {
      _settings = settings;
      _game.reduceMotion = settings.reduceMotion;
    });
    try {
      await _settingsStore.save(settings);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.settingsCouldNotBeSaved,
            ),
          ),
        );
      }
    }
  }

  void _onSuccessfulDispatch(DispatchResult result) {
    if (_settings.hapticsEnabled) unawaited(_sendSuccessHaptic());
    if (_settings.soundEnabled) {
      final cue = cueForDispatch(
        _session.state.status,
        result.boardedRiders.length,
      );
      unawaited(_audio.play(cue));
    }
  }

  Future<void> _sendSuccessHaptic() async {
    try {
      await HapticFeedback.lightImpact();
    } on Object {
      // Haptics are an optional enhancement and may be unavailable.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_session.isPaused) _game.resumeEngine();
      unawaited(_rewardedHintAds.retryLoad());
    } else {
      _game.pauseEngine();
      _queueProgressSave();
      unawaited(_audio.stopAll());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.exitLabel = AppLocalizations.of(context)!.exitLabel;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_queueProgressSave);
    _rewardedHintAds.removeListener(_onRewardedHintAdsChanged);
    _session.dispose();
    unawaited(_audio.dispose());
    unawaited(_rewardedHintAds.close());
    super.dispose();
  }

  void _queueProgressSave() {
    final store = widget.progressStore;
    if (store == null || !store.canWrite) return;

    final progress = _session.progress;
    final encoded = jsonEncode(progress.toJson());
    if (encoded == _lastQueuedProgress) return;
    _lastQueuedProgress = encoded;
    _saveQueue = _saveQueue.then((_) async {
      try {
        await store.save(progress);
        _lastSavedProgress = encoded;
        if (_storageNotice != null && mounted) {
          setState(() => _storageNotice = null);
        }
      } on Object {
        if (_lastQueuedProgress == encoded) {
          _lastQueuedProgress = _lastSavedProgress;
        }
        if (mounted) {
          setState(() => _storageNotice = StorageNotice.saveFailed);
        }
      }
    });
  }

  void _onRewardedHintAdsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onHintPressed() async {
    if (_session.earnedHints > 0) {
      _session.showHint();
      return;
    }
    if (_rewardedHintFlowInProgress) return;
    final rewardedAdsAllowed =
        _session.levelIndex >= _adFreeIntroLevelCount &&
        _rewardedHintAds.isEnabled;
    if (!rewardedAdsAllowed || !_rewardedHintAds.isReady) {
      if (rewardedAdsAllowed) {
        unawaited(_rewardedHintAds.retryLoad());
      }
      _session.showHint();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    _session.recordRewardedHintOffer();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.needRouteTipTitle),
        content: Text(l10n.watchAdForRouteTip),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.watchAd),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;

    setState(() => _rewardedHintFlowInProgress = true);
    try {
      var rewardGranted = false;
      final earned = await _rewardedHintAds.showRewardedHint(
        onRewardEarned: () {
          if (!mounted || rewardGranted) return;
          rewardGranted = _session.grantRewardedHint();
          if (rewardGranted) _session.showHint();
        },
      );
      if (!mounted) return;
      if (!earned || !rewardGranted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.routeTipNotEarned)));
      }
    } finally {
      if (mounted) setState(() => _rewardedHintFlowInProgress = false);
    }
  }

  void _pauseGame() {
    _session.pause();
    _game.pauseEngine();
    unawaited(_audio.stopAll());
  }

  void _resumeGame() {
    _session.resume();
    _game.resumeEngine();
  }

  Future<void> _showDepotPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DepotPicker(
        levels: widget.levelList,
        currentIndex: _session.levelIndex,
        completedLevelIds: _session.progress.completedLevelIds.toSet(),
        isUnlocked: _session.isLevelUnlocked,
      ),
    );
    if (!mounted ||
        selectedIndex == null ||
        selectedIndex == _session.levelIndex) {
      return;
    }

    if (_session.hasUncommittedMoves) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.leaveDepotTitle),
          content: Text(l10n.leaveDepotBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.switchDepot),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }

    _session.selectLevel(selectedIndex, discardCurrentProgress: true);
  }

  void _showHowToPlay() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.howToPlayTitle),
        content: Text(l10n.howToPlayBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }

  void _showDebugOverlay() {
    final l10n = AppLocalizations.of(context)!;
    final level = _session.level;
    final state = _session.state;
    final legalRoutes = <String>[];
    final blockedBuses = <String>[];

    for (final bus in level.buses) {
      if (!state.activeBusIds.contains(bus.id)) continue;
      final path = GameRules.routeToExit(level, state, bus.id);
      if (path == null || state.parked.length >= level.bayCount) {
        blockedBuses.add(bus.id);
      } else {
        legalRoutes.add('${bus.id}: ${path.length - 1} tiles');
      }
    }
    final solution = LevelSolver.findSolution(level, start: state);

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.debugTitle(level.id),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.debugStatus(
                  state.status.name,
                  state.moveCount,
                  state.queueIndex,
                ),
              ),
              Text(l10n.debugAuthoredSeed),
              Text(
                l10n.debugActiveBuses(
                  (state.activeBusIds.toList()..sort()).join(', '),
                ),
              ),
              Text(
                l10n.debugLegalRoutes(
                  legalRoutes.isEmpty ? 'none' : legalRoutes.join(', '),
                ),
              ),
              Text(
                l10n.debugBlockedBuses(
                  blockedBuses.isEmpty ? 'none' : blockedBuses.join(', '),
                ),
              ),
              Text(l10n.debugSolver(solution?.join(' → ') ?? 'no solution')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final level = _session.level;
        final state = _session.state;
        final pending = level.passengers.skip(state.queueIndex).toList();

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 360 || constraints.maxHeight < 700;
                final horizontalPadding = compact ? 16.0 : 20.0;
                final sectionGap = compact ? 8.0 : 12.0;
                return Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        compact ? 8 : 12,
                        horizontalPadding,
                        compact ? 8 : 16,
                      ),
                      child: Column(
                        children: [
                          _TopBar(
                            levelNumber: _session.levelIndex + 1,
                            moveCount: state.moveCount,
                            compact: compact,
                            onPause: _pauseGame,
                            onSelectDepot: _showDepotPicker,
                            showDebug: kDebugMode,
                            onDebug: _showDebugOverlay,
                            onHelp: _showHowToPlay,
                            onRestart: _session.restart,
                          ),
                          if (_storageNotice != null) ...[
                            const SizedBox(height: 8),
                            _StorageNotice(
                              notice: _storageNotice!,
                              compact: compact,
                            ),
                          ],
                          SizedBox(height: compact ? 8 : 18),
                          _ObjectiveCard(
                            message: _gameMessageText(
                              l10n,
                              _session.message,
                              level,
                              Localizations.localeOf(context).toLanguageTag(),
                            ),
                            passengerCount: pending.length,
                            compact: compact,
                            status: state.status,
                          ),
                          SizedBox(height: sectionGap),
                          _PassengerQueue(
                            passengers: pending,
                            compact: compact,
                          ),
                          SizedBox(height: sectionGap),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.depotRoute,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: const Color(0xFF8FA2BC),
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          SizedBox(height: compact ? 4 : 8),
                          if (compact)
                            SizedBox(
                              height: (constraints.maxHeight * 0.32).clamp(
                                170.0,
                                220.0,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                    maxHeight: 220,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: GameWidget<DepotGame>(game: _game),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 440,
                                    maxHeight: constraints.maxHeight * 0.58,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: GameWidget<DepotGame>(game: _game),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: compact ? 6 : 10),
                          _BayPanel(
                            parked: state.parked,
                            bayCount: level.bayCount,
                            compact: compact,
                          ),
                          SizedBox(height: sectionGap),
                          _ActionBar(
                            compact: compact,
                            canUndo: _session.canUndo,
                            earnedHints: _session.earnedHints,
                            isWon: state.status == GameStatus.won,
                            isStuck: state.status == GameStatus.stuck,
                            onUndo: _session.undo,
                            onHint: _onHintPressed,
                            onNext: _session.nextLevel,
                            onRetry: _session.restart,
                          ),
                        ],
                      ),
                    ),
                    if (_session.isPaused)
                      Positioned.fill(
                        child: _PauseOverlay(
                          onResume: _resumeGame,
                          hapticsEnabled: _settings.hapticsEnabled,
                          soundEnabled: _settings.soundEnabled,
                          reduceMotion: _settings.reduceMotion,
                          showPrivacyOptions:
                              _rewardedHintAds.privacyOptionsRequired,
                          onPrivacyOptions: () =>
                              unawaited(_rewardedHintAds.showPrivacyOptions()),
                          onHapticsChanged: (enabled) => _updateSettings(
                            _settings.copyWith(hapticsEnabled: enabled),
                          ),
                          onSoundChanged: (enabled) => _updateSettings(
                            _settings.copyWith(soundEnabled: enabled),
                          ),
                          onReduceMotionChanged: (enabled) => _updateSettings(
                            _settings.copyWith(reduceMotion: enabled),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _StorageNotice extends StatelessWidget {
  const _StorageNotice({required this.notice, required this.compact});

  final StorageNotice notice;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (notice) {
      StorageNotice.unavailable => l10n.progressStorageUnavailable,
      StorageNotice.unreadable => l10n.savedProgressUnreadable,
      StorageNotice.newerVersion => l10n.newerProgressPreserved,
      StorageNotice.resumeFailed => l10n.savedProgressCouldNotResume,
      StorageNotice.saveFailed => l10n.progressCouldNotBeSaved,
      StorageNotice.damaged => l10n.savedProgressDamaged,
      StorageNotice.recoveredBackup => l10n.savedProgressRecovered,
      StorageNotice.damagedBoth => l10n.savedProgressAndBackupDamaged,
    };
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF4A321A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.save_outlined, size: 18, color: Color(0xFFFFC857)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 10 : 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.hapticsEnabled,
    required this.soundEnabled,
    required this.reduceMotion,
    required this.showPrivacyOptions,
    required this.onPrivacyOptions,
    required this.onHapticsChanged,
    required this.onSoundChanged,
    required this.onReduceMotionChanged,
  });

  final VoidCallback onResume;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool reduceMotion;
  final bool showPrivacyOptions;
  final VoidCallback onPrivacyOptions;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onReduceMotionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: const Color(0xE6101A2A),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle_filled_rounded,
                size: 64,
                color: Color(0xFFFFC857),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.paused,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Card(
                  color: const Color(0xFF1B2940),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile.adaptive(
                        key: const ValueKey('haptics-setting'),
                        secondary: const Icon(Icons.vibration_rounded),
                        title: Text(l10n.haptics),
                        subtitle: Text(l10n.hapticsDescription),
                        value: hapticsEnabled,
                        onChanged: onHapticsChanged,
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        key: const ValueKey('sound-setting'),
                        secondary: const Icon(Icons.volume_up_rounded),
                        title: Text(l10n.soundEffects),
                        subtitle: Text(l10n.soundEffectsDescription),
                        value: soundEnabled,
                        onChanged: onSoundChanged,
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        key: const ValueKey('reduce-motion-setting'),
                        secondary: const Icon(Icons.motion_photos_off_rounded),
                        title: Text(l10n.reduceMotion),
                        subtitle: Text(l10n.reduceMotionDescription),
                        value: reduceMotion,
                        onChanged: onReduceMotionChanged,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (showPrivacyOptions) ...[
                TextButton.icon(
                  onPressed: onPrivacyOptions,
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: Text(l10n.privacyOptions),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.resume),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepotPicker extends StatelessWidget {
  const _DepotPicker({
    required this.levels,
    required this.currentIndex,
    required this.completedLevelIds,
    required this.isUnlocked,
  });

  final List<LevelSpec> levels;
  final int currentIndex;
  final Set<String> completedLevelIds;
  final bool Function(int index) isUnlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.selectDepot,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFC857),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.unlockNextDepot),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: levels.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final level = levels[index];
                    final unlocked = isUnlocked(index);
                    final completed = completedLevelIds.contains(level.id);
                    final current = index == currentIndex;
                    return ListTile(
                      enabled: unlocked,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: unlocked
                            ? const Color(0xFF334762)
                            : const Color(0xFF26354A),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(
                        l10n.depotNumberTitle(
                          (index + 1).toString().padLeft(2, '0'),
                          level.titleFor(
                            Localizations.localeOf(context).toLanguageTag(),
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        level.mechanicTags
                            .map((tag) => _localizedMechanicTag(l10n, tag))
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        current
                            ? Icons.play_circle_fill_rounded
                            : completed
                            ? Icons.check_circle_rounded
                            : unlocked
                            ? Icons.play_circle_outline_rounded
                            : Icons.lock_outline_rounded,
                        color: unlocked ? const Color(0xFFFFC857) : null,
                      ),
                      onTap: unlocked
                          ? () => Navigator.of(context).pop(index)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.levelNumber,
    required this.moveCount,
    required this.compact,
    required this.onPause,
    required this.onSelectDepot,
    required this.showDebug,
    required this.onDebug,
    required this.onHelp,
    required this.onRestart,
  });

  final int levelNumber;
  final int moveCount;
  final bool compact;
  final VoidCallback onPause;
  final VoidCallback onSelectDepot;
  final bool showDebug;
  final VoidCallback onDebug;
  final VoidCallback onHelp;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Container(
          width: compact ? 40 : 44,
          height: compact ? 40 : 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC857),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: Color(0xFF24344B),
            size: 27,
          ),
        ),
        SizedBox(width: compact ? 8 : 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'BUS-STER',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                compact
                    ? l10n.depotMoveCountCompact(
                        levelNumber.toString().padLeft(2, '0'),
                        moveCount,
                      )
                    : l10n.depotMoveCount(
                        levelNumber.toString().padLeft(2, '0'),
                        moveCount,
                      ),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8FA2BC),
                  fontSize: compact ? 9 : null,
                  letterSpacing: compact ? 0.2 : 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onPause,
          tooltip: l10n.pauseGameTooltip,
          constraints: compact
              ? const BoxConstraints.tightFor(width: 40, height: 40)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          iconSize: compact ? 20 : null,
          icon: const Icon(Icons.pause_rounded),
        ),
        IconButton(
          onPressed: onHelp,
          tooltip: l10n.howToPlayTitle,
          constraints: compact
              ? const BoxConstraints.tightFor(width: 40, height: 40)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          iconSize: compact ? 20 : null,
          icon: const Icon(Icons.help_outline_rounded),
        ),
        IconButton(
          onPressed: onSelectDepot,
          tooltip: l10n.selectDepotTooltip,
          constraints: compact
              ? const BoxConstraints.tightFor(width: 40, height: 40)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          iconSize: compact ? 20 : null,
          icon: const Icon(Icons.grid_view_rounded),
        ),
        if (showDebug)
          IconButton(
            onPressed: onDebug,
            tooltip: l10n.debugOverlayTooltip,
            constraints: compact
                ? const BoxConstraints.tightFor(width: 40, height: 40)
                : null,
            padding: compact ? EdgeInsets.zero : null,
            iconSize: compact ? 20 : null,
            icon: const Icon(Icons.bug_report_outlined),
          ),
        IconButton.filledTonal(
          onPressed: onRestart,
          tooltip: l10n.restartLevelTooltip,
          constraints: compact
              ? const BoxConstraints.tightFor(width: 40, height: 40)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          iconSize: compact ? 20 : null,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({
    required this.message,
    required this.passengerCount,
    required this.compact,
    required this.status,
  });

  final String message;
  final int passengerCount;
  final bool compact;
  final GameStatus status;

  Color get _statusColor => switch (status) {
    GameStatus.playing => const Color(0xFFFFC857),
    GameStatus.won => const Color(0xFF8DE0A7),
    GameStatus.stuck => const Color(0xFFFF806B),
  };

  IconData get _statusIcon => switch (status) {
    GameStatus.playing => Icons.alt_route_rounded,
    GameStatus.won => Icons.emoji_events_rounded,
    GameStatus.stuck => Icons.warning_amber_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 15,
        vertical: compact ? 8 : 13,
      ),
      decoration: BoxDecoration(
        color: status == GameStatus.won
            ? const Color(0xFF1B353B)
            : status == GameStatus.stuck
            ? const Color(0xFF3D2B35)
            : const Color(0xFF1B2940),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: status == GameStatus.playing
              ? const Color(0xFF2A3A54)
              : _statusColor.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          Icon(_statusIcon, color: _statusColor, size: compact ? 19 : 22),
          SizedBox(width: compact ? 7 : 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                message,
                key: ValueKey(message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: compact ? 12 : null,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$passengerCount',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFFFFC857),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerQueue extends StatelessWidget {
  const _PassengerQueue({required this.passengers, required this.compact});

  final List<RouteKind> passengers;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = passengers.take(8).toList();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 13,
        vertical: compact ? 7 : 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF17243A),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.nextRiders,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8FA2BC),
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(l10n.fifoQueue, style: const TextStyle(fontSize: 9)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: compact ? 30 : 34,
              child: visible.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.allAboard,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) => _RouteToken(
                        route: visible[index],
                        isNext: index == 0,
                      ),
                    ),
            ),
          ),
          if (passengers.length > visible.length)
            Text(
              '+${passengers.length - visible.length}',
              style: const TextStyle(
                color: Color(0xFF8FA2BC),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteToken extends StatelessWidget {
  const _RouteToken({required this.route, required this.isNext});

  final RouteKind route;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(route.colorValue),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNext ? Colors.white : Colors.white.withValues(alpha: 0.18),
          width: isNext ? 2 : 1,
        ),
        boxShadow: isNext
            ? const [BoxShadow(color: Color(0x40FFFFFF), blurRadius: 8)]
            : null,
      ),
      child: Semantics(
        label: isNext
            ? l10n.nextRiderSemantics(_localizedRouteName(l10n, route))
            : l10n.queuedRiderSemantics(_localizedRouteName(l10n, route)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            RouteSymbol(
              route: route,
              color: GamePalette.routeSymbolInk,
              size: 15,
            ),
            const ExcludeSemantics(
              child: PassengerMark(
                color: GamePalette.passengerMarkInk,
                size: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BayPanel extends StatelessWidget {
  const _BayPanel({
    required this.parked,
    required this.bayCount,
    required this.compact,
  });

  final List<ParkedBus> parked;
  final int bayCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          l10n.bays,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF8FA2BC),
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        ...List.generate(bayCount, (index) {
          final bus = index < parked.length ? parked[index] : null;
          return Expanded(
            child: Container(
              height: compact ? 40 : 48,
              margin: EdgeInsets.only(right: index == bayCount - 1 ? 0 : 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2940),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: bus == null
                      ? const Color(0xFF2A3A54)
                      : Color(bus.route.colorValue).withValues(alpha: 0.8),
                  width: bus == null ? 1 : 2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: bus == null
                    ? Semantics(
                        label: l10n.emptyDepartureBay(index + 1),
                        child: Icon(
                          Icons.local_parking_rounded,
                          key: ValueKey('empty-$index'),
                          color: const Color(0xFF71879B),
                          size: 18,
                        ),
                      )
                    : Semantics(
                        label: l10n.parkedBusSemantics(
                          _localizedRouteName(l10n, bus.route),
                          bus.loaded,
                          bus.capacity,
                        ),
                        excludeSemantics: true,
                        child: Row(
                          key: ValueKey('${bus.id}-${bus.loaded}'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MiniBusMark(route: bus.route, size: 22),
                            const SizedBox(width: 5),
                            Text(
                              '${bus.loaded}/${bus.capacity}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

String _localizedRouteName(AppLocalizations l10n, RouteKind route) =>
    switch (route) {
      RouteKind.coral => l10n.routeCoral,
      RouteKind.blue => l10n.routeBlue,
      RouteKind.mint => l10n.routeMint,
      RouteKind.gold => l10n.routeGold,
    };

String _localizedMechanicTag(AppLocalizations l10n, String tag) =>
    switch (tag) {
      'bay-pressure' => l10n.mechanicTagBayPressure,
      'bay-turnover' => l10n.mechanicTagBayTurnover,
      'branch' => l10n.mechanicTagBranch,
      'bus-blocking' => l10n.mechanicTagBusBlocking,
      'clear-path' => l10n.mechanicTagClearPath,
      'dispatch-order' => l10n.mechanicTagDispatchOrder,
      'fifo-queue' => l10n.mechanicTagFifoQueue,
      'limited-bays' => l10n.mechanicTagLimitedBays,
      'mixed-rules' => l10n.mechanicTagMixedRules,
      'review' => l10n.mechanicTagReview,
      'route-planning' => l10n.mechanicTagRoutePlanning,
      'shared-exit' => l10n.mechanicTagSharedExit,
      'shared-road' => l10n.mechanicTagSharedRoad,
      'staging' => l10n.mechanicTagStaging,
      _ => tag,
    };

String _gameMessageText(
  AppLocalizations l10n,
  GameMessage message,
  LevelSpec level,
  String locale,
) {
  switch (message.kind) {
    case GameMessageKind.levelPrompt:
      return level.tutorialPromptFor(locale);
    case GameMessageKind.defaultStart:
      return l10n.gameDefaultStart;
    case GameMessageKind.routeFinished:
      return l10n.gameRouteFinished;
    case GameMessageKind.busAlreadyLeft:
      return l10n.gameBusAlreadyLeft;
    case GameMessageKind.blockedRoute:
      return l10n.gameBlockedRoute;
    case GameMessageKind.baysFull:
      return l10n.gameFullBays;
    case GameMessageKind.noClearRoute:
      return l10n.gameNoClearRoute;
    case GameMessageKind.noRouteTips:
      return l10n.gameNoRouteTips;
    case GameMessageKind.noRouteFound:
      return l10n.gameNoRouteFound;
    case GameMessageKind.routeTip:
      return l10n.gameRouteTip(
        message.remainingHints,
        _localizedRouteName(l10n, message.route!),
      );
    case GameMessageKind.dispatchUndone:
      return l10n.gameDispatchUndone;
    case GameMessageKind.progressRestored:
      return l10n.gameProgressRestored;
    case GameMessageKind.stuckRestored:
      return l10n.gameStuckRestored;
    case GameMessageKind.wonRestored:
      return l10n.gameWonRestored;
    case GameMessageKind.dispatchFeedback:
      final details = <String>[
        if (message.depotWon)
          l10n.gameDepotClear
        else if (message.enteredBay)
          l10n.gameRouteEnteredBay(_localizedRouteName(l10n, message.route!))
        else
          l10n.gameRouteSent(_localizedRouteName(l10n, message.route!)),
        if (message.ridersBoarded > 0)
          l10n.gameRidersBoarded(message.ridersBoarded),
        if (message.busesDeparted > 0)
          l10n.gameBusesLeft(message.busesDeparted),
        if (!message.depotWon &&
            message.ridersBoarded == 0 &&
            message.busesDeparted == 0)
          l10n.gameNoRidersMatched,
      ];
      return details.join(' · ');
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.compact,
    required this.canUndo,
    required this.earnedHints,
    required this.isWon,
    required this.isStuck,
    required this.onUndo,
    required this.onHint,
    required this.onNext,
    required this.onRetry,
  });

  final bool compact;
  final bool canUndo;
  final int earnedHints;
  final bool isWon;
  final bool isStuck;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onNext;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isWon) {
      return SizedBox(
        width: double.infinity,
        height: compact ? 46 : 52,
        child: FilledButton.icon(
          onPressed: isWon ? onNext : onRetry,
          icon: Icon(
            isWon ? Icons.arrow_forward_rounded : Icons.replay_rounded,
          ),
          label: Text(isWon ? l10n.nextDepot : l10n.tryAgain),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFC857),
            foregroundColor: const Color(0xFF24344B),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
            minimumSize: Size.fromHeight(compact ? 42 : 48),
          ),
        ),
      );
    }

    if (isStuck) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canUndo ? onUndo : null,
              icon: const Icon(Icons.undo_rounded, size: 19),
              label: Text(l10n.undo),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(compact ? 42 : 48),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.replay_rounded),
              label: Text(l10n.tryAgain),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC857),
                foregroundColor: const Color(0xFF24344B),
                minimumSize: Size.fromHeight(compact ? 42 : 48),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded, size: 19),
            label: Text(l10n.undo),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(compact ? 40 : 48),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: FilledButton.icon(
            onPressed: onHint,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 19),
            label: Text(
              compact
                  ? l10n.hintCount(earnedHints)
                  : l10n.routeTipCount(earnedHints),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF243A59),
              foregroundColor: const Color(0xFFFFD36F),
              minimumSize: Size.fromHeight(compact ? 40 : 48),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
            ),
          ),
        ),
        const SizedBox(width: 9),
        IconButton.filledTonal(
          onPressed: onRetry,
          tooltip: l10n.restartLevelTooltip,
          constraints: compact
              ? const BoxConstraints.tightFor(width: 40, height: 40)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          iconSize: compact ? 20 : null,
          icon: const Icon(Icons.replay_rounded),
        ),
      ],
    );
  }
}
