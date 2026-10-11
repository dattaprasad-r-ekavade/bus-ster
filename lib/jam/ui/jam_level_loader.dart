// App shell: loads the bundled level pack, saved progress and settings, then
// shows the home (level select) screen. Play pushes [JamGameScreen]; the
// sound / haptics / reduced-motion settings are applied to it live.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/game_audio.dart';
import '../../game/game_settings.dart';
import '../../game/game_telemetry.dart';
import '../../game/settings_store.dart';
import '../jam_app_controller.dart';
import '../jam_level_codec.dart';
import '../jam_model.dart';
import '../jam_progress_store.dart';
import 'jam_game_screen.dart';
import 'jam_home_screen.dart';
import 'jam_settings_screen.dart';
import 'jam_strings.dart';
import 'jam_theme.dart';

const String jamLevelsAsset = 'assets/levels/jam_levels.json';

Future<List<JamLevel>> loadJamLevels([AssetBundle? bundle]) async {
  final source = await (bundle ?? rootBundle).loadString(jamLevelsAsset);
  return JamLevelCodec.decodeBundle(source);
}

class JamLevelLoader extends StatefulWidget {
  const JamLevelLoader({
    super.key,
    this.audioFactory,
    this.levelsLoader,
    this.progressStore,
    this.settingsStore,
    this.telemetry = const NoopGameTelemetry(),
    this.solver = computeJamSolve,
  });

  /// Creates the audio backend; defaults to silent.
  final GameAudio Function()? audioFactory;

  /// Loads the level pack; defaults to the bundled asset.
  final Future<List<JamLevel>> Function()? levelsLoader;

  /// Defaults to [FileJamProgressStore].
  final JamProgressStore? progressStore;

  /// Defaults to [SharedPreferencesGameSettingsStore].
  final GameSettingsStore? settingsStore;
  final GameTelemetry telemetry;
  final JamSolver solver;

  @override
  State<JamLevelLoader> createState() => JamLevelLoaderState();
}

class JamLevelLoaderState extends State<JamLevelLoader> {
  late final Future<JamAppController> _controller = _load();
  late final SwitchableGameAudio _audio = SwitchableGameAudio(
    widget.audioFactory?.call() ?? const SilentGameAudio(),
  );
  JamAppController? _loaded;

  /// The loaded meta state, or null while loading.
  JamAppController? get controller => _loaded;

  Future<JamAppController> _load() async {
    final levels = await (widget.levelsLoader ?? loadJamLevels)();
    final controller = await JamAppController.load(
      levels: levels,
      progressStore: widget.progressStore ?? FileJamProgressStore(),
      settingsStore:
          widget.settingsStore ?? SharedPreferencesGameSettingsStore(),
    );
    controller.addListener(_syncAudio);
    _loaded = controller;
    _syncAudio();
    return controller;
  }

  void _syncAudio() {
    final c = _loaded;
    if (c != null) _audio.enabled = c.settings.soundEnabled;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_audio.initialize());
  }

  @override
  void dispose() {
    _loaded?.removeListener(_syncAudio);
    _loaded?.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _openSettings(BuildContext context, JamAppController c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => JamSettingsScreen(controller: c)),
    );
  }

  void _play(BuildContext context, JamAppController c, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                disableAnimations:
                    media.disableAnimations || c.settings.reduceMotion,
              ),
              child: JamGameScreen(
                levels: c.levels,
                initialLevelIndex: index,
                audio: _audio,
                solver: widget.solver,
                hapticsEnabled: c.settings.hapticsEnabled,
                telemetry: widget.telemetry,
                onLevelComplete: (i, _) => unawaited(c.recordWin(i)),
                onExitToLevels: () => Navigator.of(routeContext).maybePop(),
                onOpenSettings: () => _openSettings(routeContext, c),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JamAppController>(
      future: _controller,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: JamPalette.plaza,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.loadLevelsFailed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: JamPalette.hud,
                  ),
                ),
              ),
            ),
          );
        }
        final c = snap.data;
        if (c == null) {
          return Scaffold(
            backgroundColor: JamPalette.plaza,
            body: Center(
              child: Semantics(
                label: context.l10n.loadingLevels,
                child: const CircularProgressIndicator(color: JamPalette.hud),
              ),
            ),
          );
        }
        return JamHomeScreen(
          controller: c,
          onPlay: (i) => _play(context, c, i),
          onOpenSettings: () => _openSettings(context, c),
        );
      },
    );
  }
}
