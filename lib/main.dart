import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/depot_game.dart';
import 'game/game_model.dart';
import 'game/level_loader.dart';
import 'game/game_progress.dart';
import 'game/game_session.dart';
import 'game/game_settings.dart';
import 'game/progress_store.dart';
import 'game/settings_store.dart';

Future<void> main({
  bool loadSavedProgress = true,
  ProgressFileStore? progressStoreOverride,
  GameSettingsStore? settingsStoreOverride,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final levelList = await loadBundledLevels();
  if (!loadSavedProgress) {
    runApp(
      BussterApp(
        levelList: levelList,
        progressStore: progressStoreOverride,
        settingsStore: settingsStoreOverride,
      ),
    );
    return;
  }

  ProgressFileStore? progressStore;
  GameProgress? savedProgress;
  String? startupWarning;
  try {
    progressStore =
        progressStoreOverride ?? await ProgressFileStore.inApplicationSupport();
    savedProgress = await progressStore.load();
    startupWarning = progressStore.loadWarning;
  } on Object {
    startupWarning = progressStore == null
        ? 'Progress storage is unavailable on this device.'
        : progressStore.canWrite
        ? 'Saved progress could not be read. Its files were preserved.'
        : 'Saved progress belongs to a newer app version and was preserved.';
  }

  runApp(
    BussterApp(
      levelList: levelList,
      progressStore: progressStore,
      initialProgress: savedProgress,
      startupWarning: startupWarning,
      settingsStore: settingsStoreOverride,
    ),
  );
}

class BussterApp extends StatelessWidget {
  const BussterApp({
    super.key,
    required this.levelList,
    this.progressStore,
    this.initialProgress,
    this.startupWarning,
    this.settingsStore,
  });

  final List<LevelSpec> levelList;
  final ProgressFileStore? progressStore;
  final GameProgress? initialProgress;
  final String? startupWarning;
  final GameSettingsStore? settingsStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus-ster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101A2A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC857),
          brightness: Brightness.dark,
          surface: const Color(0xFF1B2940),
        ),
        useMaterial3: true,
      ),
      home: DepotScreen(
        levelList: levelList,
        progressStore: progressStore,
        initialProgress: initialProgress,
        startupWarning: startupWarning,
        settingsStore: settingsStore,
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
  });

  final List<LevelSpec> levelList;
  final ProgressFileStore? progressStore;
  final GameProgress? initialProgress;
  final String? startupWarning;
  final GameSettingsStore? settingsStore;

  @override
  State<DepotScreen> createState() => _DepotScreenState();
}

class _DepotScreenState extends State<DepotScreen> with WidgetsBindingObserver {
  late final GameSession _session;
  late final DepotGame _game;
  late final GameSettingsStore _settingsStore;
  GameSettings _settings = GameSettings.defaults;
  int _settingsChanges = 0;
  String? _storageNotice;
  String? _lastSavedProgress;
  String? _lastQueuedProgress;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsStore =
        widget.settingsStore ?? SharedPreferencesGameSettingsStore();
    _session = GameSession(levelList: widget.levelList);
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
        _storageNotice =
            'Saved progress could not be resumed. Start this depot again.';
      }
    }
    _session.addListener(_queueProgressSave);
  }

  Future<void> _loadSettings() async {
    final changesBeforeLoad = _settingsChanges;
    try {
      final loaded = await _settingsStore.load();
      if (!mounted || changesBeforeLoad != _settingsChanges) return;
      setState(() => _settings = loaded);
      _game.reduceMotion = loaded.reduceMotion;
    } on Object {
      // Settings are optional; the game remains playable with defaults.
    }
  }

  Future<void> _updateSettings(GameSettings settings) async {
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
          const SnackBar(content: Text('Settings could not be saved.')),
        );
      }
    }
  }

  void _onSuccessfulDispatch() {
    if (_settings.hapticsEnabled) unawaited(_sendSuccessHaptic());
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
    } else {
      _game.pauseEngine();
      _queueProgressSave();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_queueProgressSave);
    _session.dispose();
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
          setState(
            () =>
                _storageNotice = 'Progress could not be saved on this device.',
          );
        }
      }
    });
  }

  void _pauseGame() {
    _session.pause();
    _game.pauseEngine();
  }

  void _resumeGame() {
    _session.resume();
    _game.resumeEngine();
  }

  Future<void> _showDepotPicker() async {
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
          title: const Text('Leave this depot?'),
          content: const Text(
            'Switching depots will restart your current attempt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('SWITCH DEPOT'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }

    _session.selectLevel(selectedIndex, discardCurrentProgress: true);
  }

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to play'),
        content: const Text(
          'Tap a bus when a clear road connects it to the EXIT.\n\n'
          'The bus waits in a departure bay. Riders board from the front '
          'of the queue, in order, and only ride a matching route.\n\n'
          'A full bus leaves and opens its bay. Clear every rider to finish '
          'the depot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  void _showDebugOverlay() {
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
                'DEBUG · ${level.id}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${state.status.name} · Moves: ${state.moveCount} · '
                'Queue index: ${state.queueIndex}',
              ),
              Text('Seed: authored level (no random seed)'),
              Text('Active buses: ${state.activeBusIds.toList()..sort()}'),
              Text(
                'Legal routes: ${legalRoutes.isEmpty ? 'none' : legalRoutes.join(', ')}',
              ),
              Text(
                'Blocked buses: ${blockedBuses.isEmpty ? 'none' : blockedBuses.join(', ')}',
              ),
              Text('Solver: ${solution?.join(' → ') ?? 'no solution'}'),
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
                              message: _storageNotice!,
                              compact: compact,
                            ),
                          ],
                          SizedBox(height: compact ? 8 : 18),
                          _ObjectiveCard(
                            message: _session.message,
                            passengerCount: pending.length,
                            compact: compact,
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
                              'DEPOT ROUTE',
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
                            onHint: _session.showHint,
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
                          reduceMotion: _settings.reduceMotion,
                          onHapticsChanged: (enabled) => _updateSettings(
                            _settings.copyWith(hapticsEnabled: enabled),
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
  const _StorageNotice({required this.message, required this.compact});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
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
    required this.reduceMotion,
    required this.onHapticsChanged,
    required this.onReduceMotionChanged,
  });

  final VoidCallback onResume;
  final bool hapticsEnabled;
  final bool reduceMotion;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onReduceMotionChanged;

  @override
  Widget build(BuildContext context) {
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
                'PAUSED',
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
                        title: const Text('Haptics'),
                        subtitle: const Text('A light pulse on a valid move'),
                        value: hapticsEnabled,
                        onChanged: onHapticsChanged,
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        key: const ValueKey('reduce-motion-setting'),
                        secondary: const Icon(Icons.motion_photos_off_rounded),
                        title: const Text('Reduce motion'),
                        subtitle: const Text('Skip moving bus animations'),
                        value: reduceMotion,
                        onChanged: onReduceMotionChanged,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('RESUME'),
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
                'SELECT DEPOT',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFC857),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Clear a depot to unlock the next one.'),
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
                        'DEPOT ${(index + 1).toString().padLeft(2, '0')} · ${level.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        level.mechanicTags.join(' · '),
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
                    ? 'DEPOT ${levelNumber.toString().padLeft(2, '0')} · $moveCount'
                    : 'DEPOT ${levelNumber.toString().padLeft(2, '0')}  ·  $moveCount MOVES',
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
          tooltip: 'Pause game',
          constraints: compact
              ? const BoxConstraints.tightFor(width: 40, height: 40)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          iconSize: compact ? 20 : null,
          icon: const Icon(Icons.pause_rounded),
        ),
        IconButton(
          onPressed: onHelp,
          tooltip: 'How to play',
          constraints: compact
              ? const BoxConstraints.tightFor(width: 40, height: 40)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          iconSize: compact ? 20 : null,
          icon: const Icon(Icons.help_outline_rounded),
        ),
        IconButton(
          onPressed: onSelectDepot,
          tooltip: 'Select depot',
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
            tooltip: 'Debug overlay',
            constraints: compact
                ? const BoxConstraints.tightFor(width: 40, height: 40)
                : null,
            padding: compact ? EdgeInsets.zero : null,
            iconSize: compact ? 20 : null,
            icon: const Icon(Icons.bug_report_outlined),
          ),
        IconButton.filledTonal(
          onPressed: onRestart,
          tooltip: 'Restart level',
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
  });

  final String message;
  final int passengerCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 15,
        vertical: compact ? 8 : 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2940),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF2A3A54)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.alt_route_rounded,
            color: Color(0xFFFFC857),
            size: compact ? 19 : 22,
          ),
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
                'NEXT RIDERS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8FA2BC),
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text('FIFO QUEUE', style: TextStyle(fontSize: 9)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: compact ? 30 : 34,
              child: visible.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'All aboard!',
                        style: TextStyle(fontSize: 12),
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
      child: Text(
        route.symbol,
        style: const TextStyle(
          color: Color(0xFF101A2A),
          fontSize: 16,
          fontWeight: FontWeight.w900,
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
    return Row(
      children: [
        Text(
          'BAYS',
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
                    ? Icon(
                        Icons.add_rounded,
                        key: ValueKey('empty-$index'),
                        color: const Color(0xFF566982),
                        size: 18,
                      )
                    : Row(
                        key: ValueKey('${bus.id}-${bus.loaded}'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            bus.route.symbol,
                            style: TextStyle(
                              color: Color(bus.route.colorValue),
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
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
          );
        }),
      ],
    );
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
    if (isWon || isStuck) {
      return SizedBox(
        width: double.infinity,
        height: compact ? 46 : 52,
        child: FilledButton.icon(
          onPressed: isWon ? onNext : onRetry,
          icon: Icon(
            isWon ? Icons.arrow_forward_rounded : Icons.replay_rounded,
          ),
          label: Text(isWon ? 'NEXT DEPOT' : 'TRY AGAIN'),
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

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded, size: 19),
            label: const Text('UNDO'),
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
              compact ? 'HINT $earnedHints' : 'ROUTE TIP · $earnedHints',
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
          tooltip: 'Restart level',
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
