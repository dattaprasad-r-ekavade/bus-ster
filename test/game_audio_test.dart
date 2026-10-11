import 'package:busster/game/game_audio.dart';
import 'package:busster/game/game_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the dispatch cue when no riders board', () {
    expect(cueForDispatch(GameStatus.playing, 0), GameAudioCue.dispatch);
  });

  test('uses the boarding cue when riders board', () {
    expect(cueForDispatch(GameStatus.playing, 2), GameAudioCue.boarding);
  });

  test('uses the depot-clear cue on victory', () {
    expect(cueForDispatch(GameStatus.won, 0), GameAudioCue.depotClear);
  });

  test('uses the stuck cue when a dispatch leaves no solution', () {
    expect(cueForDispatch(GameStatus.stuck, 0), GameAudioCue.stuck);
  });
}
