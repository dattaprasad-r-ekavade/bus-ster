import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'game_model.dart';

enum GameAudioCue { dispatch, boarding, depotClear, stuck }

GameAudioCue cueForDispatch(GameStatus status, int boardedRiders) =>
    switch (status) {
      GameStatus.won => GameAudioCue.depotClear,
      GameStatus.stuck => GameAudioCue.stuck,
      GameStatus.playing when boardedRiders > 0 => GameAudioCue.boarding,
      GameStatus.playing => GameAudioCue.dispatch,
    };

abstract interface class GameAudio {
  Future<void> initialize();
  Future<void> play(GameAudioCue cue);
  Future<void> stopAll();
  Future<void> dispose();
}

class SilentGameAudio implements GameAudio {
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
class AudioplayersGameAudio implements GameAudio {
  AudioplayersGameAudio();

  static const _paths = <GameAudioCue, String>{
    GameAudioCue.dispatch: 'audio/dispatch.wav',
    GameAudioCue.boarding: 'audio/boarding.wav',
    GameAudioCue.depotClear: 'audio/depot_clear.wav',
    GameAudioCue.stuck: 'audio/stuck.wav',
  };
  static const _volumes = <GameAudioCue, double>{
    GameAudioCue.dispatch: 0.48,
    GameAudioCue.boarding: 0.5,
    GameAudioCue.depotClear: 0.52,
    GameAudioCue.stuck: 0.4,
  };

  final Map<GameAudioCue, AudioPool> _pools = {};
  final Map<GameAudioCue, Duration> _durations = {};
  final Map<StopFunction, Timer> _activeSounds = {};
  Future<void>? _initialization;
  bool _disposed = false;
  bool _unavailable = false;

  bool get isReady =>
      !_disposed &&
      !_unavailable &&
      _pools.length == GameAudioCue.values.length;

  @override
  Future<void> initialize() => _initialization ??= _preload();

  Future<void> _preload() async {
    try {
      for (final cue in GameAudioCue.values) {
        if (_disposed) return;
        final pool = await AudioPool.createFromAsset(
          path: _paths[cue]!,
          maxPlayers: 2,
          minPlayers: 1,
          playerMode: PlayerMode.lowLatency,
        );
        if (_disposed) {
          await pool.dispose();
          return;
        }
        _pools[cue] = pool;
        _durations[cue] =
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
      final pool = _pools[cue];
      if (pool == null) return;
      final stop = await pool.start(volume: _volumes[cue]!);
      final duration = _durations[cue] ?? const Duration(milliseconds: 350);
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
