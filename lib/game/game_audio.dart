import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Semantic sound cues for the bus-jam loop. Several cues may share one
/// bundled WAV asset; see [AudioplayersGameAudio.assetFor].
enum GameAudioCue { tap, blocked, board, depart, win, lose }

/// Sound effects boundary. Implementations must never throw into gameplay.
abstract class GameAudio {
  const GameAudio();

  Future<void> initialize();
  Future<void> play(GameAudioCue cue);
  Future<void> stopAll();
  Future<void> dispose();

  Future<void> playTap() => play(GameAudioCue.tap);
  Future<void> playBlocked() => play(GameAudioCue.blocked);
  Future<void> playBoard() => play(GameAudioCue.board);
  Future<void> playDepart() => play(GameAudioCue.depart);
  Future<void> playWin() => play(GameAudioCue.win);
  Future<void> playLose() => play(GameAudioCue.lose);
}

class SilentGameAudio extends GameAudio {
  const SilentGameAudio();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> play(GameAudioCue cue) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

/// Preloads short, locally bundled Bus-ster effects into Android low-latency
/// pools. Audio errors never interrupt puzzle input or progress saves.
class AudioplayersGameAudio extends GameAudio {
  AudioplayersGameAudio();

  static const _assets = <GameAudioCue, String>{
    GameAudioCue.tap: 'audio/dispatch.wav',
    GameAudioCue.blocked: 'audio/stuck.wav',
    GameAudioCue.board: 'audio/boarding.wav',
    GameAudioCue.depart: 'audio/dispatch.wav',
    GameAudioCue.win: 'audio/depot_clear.wav',
    GameAudioCue.lose: 'audio/stuck.wav',
  };
  static const _volumes = <GameAudioCue, double>{
    GameAudioCue.tap: 0.36,
    GameAudioCue.blocked: 0.32,
    GameAudioCue.board: 0.5,
    GameAudioCue.depart: 0.48,
    GameAudioCue.win: 0.52,
    GameAudioCue.lose: 0.42,
  };

  /// Bundled asset path (relative to `assets/`) played for [cue].
  static String assetFor(GameAudioCue cue) => _assets[cue]!;

  /// Playback volume for [cue] in the range 0..1.
  static double volumeFor(GameAudioCue cue) => _volumes[cue]!;

  static Set<String> get assetPaths => _assets.values.toSet();

  final Map<String, AudioPool> _pools = {};
  final Map<String, Duration> _durations = {};
  final Map<StopFunction, Timer> _activeSounds = {};
  Future<void>? _initialization;
  bool _disposed = false;
  bool _unavailable = false;

  bool get isReady =>
      !_disposed && !_unavailable && _pools.length == assetPaths.length;

  @override
  Future<void> initialize() => _initialization ??= _preload();

  Future<void> _preload() async {
    try {
      for (final path in assetPaths) {
        if (_disposed) return;
        final pool = await AudioPool.createFromAsset(
          path: path,
          maxPlayers: 2,
          minPlayers: 1,
          playerMode: PlayerMode.lowLatency,
        );
        if (_disposed) {
          await pool.dispose();
          return;
        }
        _pools[path] = pool;
        _durations[path] =
            await pool.getDuration() ?? const Duration(milliseconds: 350);
      }
    } on Object {
      _unavailable = true;
      await Future.wait(_pools.values.map((pool) => pool.dispose()));
      _pools.clear();
    }
  }

  @override
  Future<void> play(GameAudioCue cue) async {
    if (_disposed || _unavailable) return;
    try {
      await initialize();
      if (_disposed || _unavailable) return;
      final path = assetFor(cue);
      final pool = _pools[path];
      if (pool == null) return;
      final stop = await pool.start(volume: volumeFor(cue));
      final duration = _durations[path] ?? const Duration(milliseconds: 350);
      late final Timer timer;
      timer = Timer(duration + const Duration(milliseconds: 65), () {
        _activeSounds.remove(stop);
        unawaited(_stopQuietly(stop));
      });
      _activeSounds[stop] = timer;
    } on Object {
      // Keep sound optional on unsupported devices and in silent/audio-focus
      // states. The screen reader and haptic settings remain independent.
    }
  }

  @override
  Future<void> stopAll() async {
    final active = Map<StopFunction, Timer>.of(_activeSounds);
    _activeSounds.clear();
    for (final entry in active.entries) {
      entry.value.cancel();
      await _stopQuietly(entry.key);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopAll();
    try {
      await _initialization;
    } on Object {
      // _preload already converts platform errors to silent fallback.
    }
    await Future.wait(_pools.values.map((pool) => pool.dispose()));
    _pools.clear();
    _durations.clear();
  }

  Future<void> _stopQuietly(StopFunction stop) async {
    try {
      await stop();
    } on Object {
      // A player may have completed while Android was changing lifecycle.
    }
  }
}
