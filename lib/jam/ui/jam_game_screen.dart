// Bus Jam play screen.
//
// Rules first, visuals second: every tap goes straight to
// [JamSession.tap]; the returned events are handed to the
// [JamChoreographer], which animates them on its own clock. Input is never
// locked while buses move; Undo / Retry / level change snap the visual model
// back to the true state.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../game/game_audio.dart';
import '../../game/game_telemetry.dart';
import '../jam_model.dart';
import '../jam_solver.dart';
import 'board_painter.dart';
import 'jam_choreographer.dart';
import 'jam_hud.dart';
import 'jam_layout.dart';
import 'jam_overlays.dart';
import 'jam_strings.dart';
import 'jam_theme.dart';
import 'scene_painter.dart';

/// Runs the solver for hints; injectable so tests can stay synchronous.
typedef JamSolver = Future<SolveResult> Function(JamSolveRequest request);

/// Default [JamSolver]: solves on a background isolate.
Future<SolveResult> computeJamSolve(JamSolveRequest request) =>
    compute(solveJamRequest, request);

/// Called once each time a level is won.
typedef JamLevelCompleteCallback =
    void Function(int levelIndex, JamLevel level);

class JamGameScreen extends StatefulWidget {
  const JamGameScreen({
    super.key,
    required this.levels,
    this.initialLevelIndex = 0,
    this.onLevelComplete,
    this.audio = const SilentGameAudio(),
    this.solver = computeJamSolve,
    this.hapticsEnabled = true,
    this.telemetry = const NoopGameTelemetry(),
    this.onExitToLevels,
    this.onOpenSettings,
  });

  final List<JamLevel> levels;
  final int initialLevelIndex;
  final JamLevelCompleteCallback? onLevelComplete;
  final GameAudio audio;
  final JamSolver solver;
  final bool hapticsEnabled;
  final GameTelemetry telemetry;

  /// Pause-menu "Levels" entry; hidden when null.
  final VoidCallback? onExitToLevels;

  /// Pause-menu "Settings" entry; hidden when null. The game stays paused
  /// while settings are open.
  final VoidCallback? onOpenSettings;

  @override
  State<JamGameScreen> createState() => JamGameScreenState();
}

@visibleForTesting
class JamGameScreenState extends State<JamGameScreen>
    with SingleTickerProviderStateMixin {
  late int _levelIndex;
  late JamSession _session;
  JamLayout? _layout;
  JamChoreographer? _chor;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  final ValueNotifier<int> _passengersLeft = ValueNotifier(0);
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  bool _choreoBusy = false;
  bool _paused = false;
  bool _reduceMotion = false;
  bool _resultAnnounced = false;
  bool _hintRunning = false;
  int _generation = 0;
  String? _tutorialTarget;
  double _tutorialStart = 0;
  String? _toast;
  double _toastUntil = 0;

  JamLevel get level => _session.level;
  JamSession get session => _session;
  int get levelIndex => _levelIndex;

  /// Whether the visual layer is still playing out moves.
  bool get isAnimating => _choreoBusy;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _levelIndex = widget.initialLevelIndex.clamp(0, widget.levels.length - 1);
    _session = JamSession(widget.levels[_levelIndex]);
    _passengersLeft.value = level.passengers.length;
    _refreshTutorial();
    _track(GameEventNames.levelStart);
  }

  void _track(String name, [Map<String, Object> extra = const {}]) {
    try {
      widget.telemetry.record(
        GameEvent(
          name: name,
          parameters: {
            'level_id': level.id,
            'level_index': _levelIndex,
            ...extra,
          },
        ),
      );
    } on Object {
      // Telemetry is best-effort and must never break play.
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _passengersLeft.dispose();
    super.dispose();
  }

  // ---- Clock -------------------------------------------------------------

  double get _now => _clock.value;

  void _ensureTicking() {
    if (_paused || _ticker.isActive) return;
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final chor = _chor;
    if (chor == null) {
      _ticker.stop();
      return;
    }
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastElapsed = elapsed;
    final t = _now + dt;
    for (final cue in chor.takeCues(t)) {
      switch (cue.kind) {
        case ChoreoCueKind.board:
          unawaited(widget.audio.playBoard());
        case ChoreoCueKind.depart:
          unawaited(widget.audio.playDepart());
        case ChoreoCueKind.park:
          break;
      }
    }
    _clock.value = t;
    _passengersLeft.value = level.passengers.length - chor.firstQueuedAt(t);
    if (_choreoBusy && !chor.busyAt(t)) {
      setState(() => _choreoBusy = false);
      _announceResult();
    }
    if (!chor.animatingAt(t)) {
      _ticker.stop();
      // Compact the finished timeline into the resting picture.
      chor.snap(_session.state);
    }
  }

  // ---- Input -------------------------------------------------------------

  void _onBusTap(String id) {
    final chor = _chor;
    if (chor == null || _paused || !_session.state.isPlaying) return;
    final result = _session.tap(id);
    if (!result.moved) {
      _onBlocked(result.block!, id);
      return;
    }
    _generation++;
    unawaited(widget.audio.playTap());
    if (widget.hapticsEnabled) unawaited(HapticFeedback.selectionClick());
    if (_reduceMotion) {
      chor.snap(_session.state);
      _passengersLeft.value =
          level.passengers.length - _session.state.passengerIndex;
      setState(() => _choreoBusy = false);
      _announceResult();
    } else {
      chor.play(result.events, _now);
      setState(() => _choreoBusy = true);
      _ensureTicking();
    }
    _refreshTutorial();
  }

  void _onBlocked(JamBlock block, String id) {
    final chor = _chor!;
    switch (block.reason) {
      case JamBlockReason.vehicle:
        if (_reduceMotion) {
          chor.flashes[block.blockerId!] = _now;
          chor.holdUntil(_now + JamChoreographer.lurchTime);
        } else {
          chor.lurch(id, block.blockerId, _now);
        }
      case JamBlockReason.fullBays:
        chor.lurch(id, null, _now);
        chor.pulseStalls(_now);
      case JamBlockReason.gone:
      case JamBlockReason.notPlaying:
        return;
    }
    unawaited(widget.audio.playBlocked());
    if (widget.hapticsEnabled) unawaited(HapticFeedback.mediumImpact());
    _ensureTicking();
  }

  void _undo() {
    if (_paused || !_session.undo()) return;
    _track(GameEventNames.undo);
    _resetVisuals();
  }

  void _retry() {
    _session.retry();
    _track(GameEventNames.retry);
    _paused = false;
    _resetVisuals();
  }

  void _goToLevel(int index) {
    _levelIndex = index % widget.levels.length;
    _session = JamSession(widget.levels[_levelIndex]);
    _layout = null;
    _chor = null;
    _paused = false;
    _track(GameEventNames.levelStart);
    _resetVisuals();
  }

  void _nextLevel() => _goToLevel(_levelIndex + 1);

  void _resetVisuals() {
    _generation++;
    _chor?.snap(_session.state);
    _choreoBusy = false;
    _resultAnnounced = false;
    _toast = null;
    _tutorialTarget = null;
    _passengersLeft.value =
        level.passengers.length - _session.state.passengerIndex;
    if (_ticker.isActive) _ticker.stop();
    setState(() {});
    _announceResult();
    _refreshTutorial();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _ticker.stop();
    } else if (_chor?.animatingAt(_now) ?? false) {
      _ensureTicking();
    }
  }

  Future<void> _hint() async {
    final chor = _chor;
    if (chor == null || _hintRunning || !_session.state.isPlaying) return;
    _hintRunning = true;
    _track(GameEventNames.hintUsed);
    final gen = _generation;
    SolveResult result;
    try {
      result = await widget.solver(
        JamSolveRequest(level, from: _session.state),
      );
    } on Object {
      result = const Unknown(nodeLimit: 0, nodesExpanded: 0);
    } finally {
      _hintRunning = false;
    }
    if (!mounted || gen != _generation || _chor == null) return;
    switch (result) {
      case Solvable(:final path) when path.isNotEmpty:
        _chor!.hint(path.first, _now);
        _ensureTicking();
        setState(() {});
      case Solvable():
        break;
      case Unsolvable():
        _showToast(context.l10n.hintUnsolvable);
      case Unknown():
        _showToast(context.l10n.hintUnknown);
    }
  }

  void _showToast(String text) {
    _toast = text;
    _toastUntil = _now + 2.2;
    _chor?.holdUntil(_toastUntil);
    _ensureTicking();
    setState(() {});
  }

  void _refreshTutorial() {
    final state = _session.state;
    if (level.hint == null || !state.isPlaying) {
      _tutorialTarget = null;
      return;
    }
    final gen = _generation;
    widget.solver(JamSolveRequest(level, from: state)).then((result) {
      if (!mounted || gen != _generation) return;
      final target = result is Solvable && result.path.isNotEmpty
          ? result.path.first
          : null;
      setState(() {
        _tutorialTarget = target;
        _tutorialStart = _now;
      });
      if (!_reduceMotion) {
        _chor?.holdUntil(_now + JamScenePainter.handBobTime);
        _ensureTicking();
      }
    }, onError: (Object _) {});
  }

  void _announceResult() {
    if (_resultAnnounced || _choreoBusy) return;
    final status = _session.state.status;
    if (status == JamStatus.playing) return;
    _resultAnnounced = true;
    _track(
      status == JamStatus.won
          ? GameEventNames.levelWin
          : GameEventNames.levelLose,
      {'moves': _session.state.moveCount},
    );
    if (status == JamStatus.won) {
      unawaited(widget.audio.playWin());
      widget.onLevelComplete?.call(_levelIndex, level);
    } else {
      unawaited(widget.audio.playLose());
    }
  }

  // ---- Build -------------------------------------------------------------

  JamChoreographer _ensureLayout(Size size) {
    var layout = _layout;
    if (layout == null || layout.size != size) {
      layout = JamLayout.compute(size, level);
      _layout = layout;
      final chor = _chor;
      if (chor == null) {
        _chor = JamChoreographer(level: level, layout: layout)
          ..snap(_session.state);
      } else {
        chor.layout = layout;
        chor.snap(_session.state);
        _choreoBusy = false;
      }
    }
    return _chor!;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final state = _session.state;
    final showWin = state.status == JamStatus.won && !_choreoBusy;
    final showLose = state.status == JamStatus.lost && !_choreoBusy;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: JamPalette.grass,
        body: Stack(
          children: [
            Column(
              children: [
                ColoredBox(
                  color: JamPalette.plaza,
                  child: SafeArea(
                    bottom: false,
                    child: JamHud(
                      levelNumber: _levelIndex + 1,
                      passengersLeft: _passengersLeft,
                      canUndo: _session.canUndo,
                      onUndo: _undo,
                      onRetry: _retry,
                      onHint: () => unawaited(_hint()),
                      onMenu: _togglePause,
                    ),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, c) =>
                          _buildScene(Size(c.maxWidth, c.maxHeight), state),
                    ),
                  ),
                ),
              ],
            ),
            if (showWin)
              JamWinOverlay(
                key: ValueKey('win-$_levelIndex'),
                onNext: _nextLevel,
                reduceMotion: _reduceMotion,
              )
            else if (showLose)
              JamLoseOverlay(
                baysFull: state.freeBays == 0,
                onUndo: _undo,
                onRetry: _retry,
              )
            else if (_paused)
              JamPauseOverlay(
                onResume: _togglePause,
                onRetry: _retry,
                onLevels: widget.onExitToLevels,
                onSettings: widget.onOpenSettings,
                onSkip: kDebugMode ? _nextLevel : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScene(Size size, JamState state) {
    final chor = _ensureLayout(size);
    final layout = _layout!;
    final children = <Widget>[
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: JamBoardPainter(layout, level.bayCount)),
        ),
      ),
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: JamScenePainter(
              chor: chor,
              layout: layout,
              state: state,
              clock: _clock,
              tutorialTarget: _tutorialTarget,
              tutorialStart: _tutorialStart,
            ),
          ),
        ),
      ),
      for (final v in level.vehicles)
        if (state.remaining.contains(v.id))
          Positioned.fromRect(
            key: ValueKey('jam-bus-${v.id}'),
            rect: layout.footprint(v),
            child: Semantics(
              button: true,
              label: context.l10n.busLabel(v),
              excludeSemantics: true,
              onTap: () => _onBusTap(v.id),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onBusTap(v.id),
              ),
            ),
          ),
    ];

    final bubbleText = context.l10n.tutorialHint(level.hint);
    final target = _tutorialTarget;
    if (bubbleText != null &&
        target != null &&
        state.isPlaying &&
        state.moveCount < 2 &&
        state.remaining.contains(target)) {
      final rect = layout.footprint(level.vehicle(target));
      // Pin the bubble to the lot end that hides fewer buses (ties: the
      // end farther from the pointed-at bus).
      final lot = layout.lotRect;
      int hidden(Rect band) => level.vehicles
          .where(
            (v) =>
                state.remaining.contains(v.id) &&
                layout.footprint(v).overlaps(band),
          )
          .length;
      final topHits = hidden(
        Rect.fromLTRB(lot.left, lot.top, lot.right, lot.top + 76),
      );
      final bottomHits = hidden(
        Rect.fromLTRB(lot.left, lot.bottom - 76, lot.right, lot.bottom),
      );
      final below = topHits == bottomHits
          ? rect.center.dy > lot.center.dy
          : topHits < bottomHits;
      children.add(
        JamTutorialBubble(
          key: const ValueKey('jam-tutorial-bubble'),
          text: bubbleText,
          anchor: below
              ? Offset(layout.lotRect.center.dx, layout.lotRect.top + 8)
              : Offset(layout.lotRect.center.dx, layout.lotRect.bottom - 8),
          bounds: size,
          below: below,
        ),
      );
    }

    if (_toast != null) {
      children.add(
        Positioned(
          left: 16,
          right: 16,
          bottom: layout.roadW + 24,
          child: ValueListenableBuilder<double>(
            valueListenable: _clock,
            builder: (context, t, _) => t < _toastUntil
                ? Center(child: JamToast(text: _toast!))
                : const SizedBox.shrink(),
          ),
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }
}
