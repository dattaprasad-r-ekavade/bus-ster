import 'dart:io';

import 'package:busster/game/game_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every cue maps to a bundled WAV asset with a sane volume', () {
    for (final cue in GameAudioCue.values) {
      final asset = AudioplayersGameAudio.assetFor(cue);
      expect(asset, endsWith('.wav'));
      expect(File('assets/$asset').existsSync(), isTrue, reason: '$cue');
      expect(AudioplayersGameAudio.volumeFor(cue), inInclusiveRange(0, 1));
    }
  });

  test('convenience methods route to the matching cue', () async {
    final audio = _RecordingAudio();
    await audio.playTap();
    await audio.playBlocked();
    await audio.playBoard();
    await audio.playDepart();
    await audio.playWin();
    await audio.playLose();
    expect(audio.cues, GameAudioCue.values);
  });

  test('silent audio is a no-op', () async {
    const audio = SilentGameAudio();
    await audio.initialize();
    await audio.playWin();
    await audio.stopAll();
    await audio.dispose();
  });
}

class _RecordingAudio extends GameAudio {
  final List<GameAudioCue> cues = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> play(GameAudioCue cue) async => cues.add(cue);

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}
