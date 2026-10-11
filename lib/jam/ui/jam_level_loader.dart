// Loads the bundled level pack and hands it to [JamGameScreen].
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/game_audio.dart';
import '../jam_level_codec.dart';
import '../jam_model.dart';
import 'jam_game_screen.dart';
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
    this.initialLevelIndex = 0,
    this.onLevelComplete,
  });

  /// Creates the audio backend; defaults to silent.
  final GameAudio Function()? audioFactory;
  final int initialLevelIndex;
  final JamLevelCompleteCallback? onLevelComplete;

  @override
  State<JamLevelLoader> createState() => _JamLevelLoaderState();
}

class _JamLevelLoaderState extends State<JamLevelLoader> {
  late final Future<List<JamLevel>> _levels = loadJamLevels();
  late final GameAudio _audio =
      widget.audioFactory?.call() ?? const SilentGameAudio();

  @override
  void initState() {
    super.initState();
    _audio.initialize();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JamLevel>>(
      future: _levels,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: JamPalette.plaza,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load levels.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final levels = snap.data;
        if (levels == null || levels.isEmpty) {
          return const Scaffold(
            backgroundColor: JamPalette.plaza,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return JamGameScreen(
          levels: levels,
          audio: _audio,
          initialLevelIndex: widget.initialLevelIndex,
          onLevelComplete: widget.onLevelComplete,
        );
      },
    );
  }
}
