import 'package:busster/game/game_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event parameters are immutable snapshots', () {
    final source = <String, Object>{'level_id': 'jam-01'};
    final event = GameEvent(
      name: GameEventNames.levelStarted,
      parameters: source,
    );
    source['level_id'] = 'changed';

    expect(event.parameters['level_id'], 'jam-01');
    expect(() => event.parameters['extra'] = 1, throwsUnsupportedError);
  });

  test('the default adapter keeps gameplay offline', () {
    const telemetry = NoopGameTelemetry();
    expect(
      () => telemetry.record(
        GameEvent(name: GameEventNames.levelCompleted, parameters: const {}),
      ),
      returnsNormally,
    );
  });
}
