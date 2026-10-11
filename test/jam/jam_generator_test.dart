import 'package:busster/jam/jam_generator.dart';
import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_solver.dart';
import 'package:flutter_test/flutter_test.dart';

const _small = JamGeneratorSpec(
  id: 'gen-small',
  width: 5,
  height: 6,
  minVehicles: 7,
  maxVehicles: 10,
  colorCount: 3,
  bayCount: 5,
  targetFailRate: 0.35,
  playouts: 150,
  maxAttempts: 60,
);

void main() {
  test('same seed produces the same level', () {
    final a = generateJamLevel(_small, seed: 42);
    final b = generateJamLevel(_small, seed: 42);
    expect(
      JamLevelCodec.encodeLevel(b.level),
      JamLevelCodec.encodeLevel(a.level),
    );
    expect(b.plannedOrder, a.plannedOrder);
    expect(b.failRate, a.failRate);
  });

  test('different seeds produce different levels', () {
    final a = generateJamLevel(_small, seed: 1);
    final b = generateJamLevel(_small, seed: 2);
    expect(
      JamLevelCodec.encodeLevel(b.level),
      isNot(JamLevelCodec.encodeLevel(a.level)),
    );
  });

  test('generated levels meet the spec and are solvable', () {
    const specs = [
      _small,
      JamGeneratorSpec(
        id: 'gen-four-colours',
        width: 6,
        height: 7,
        minVehicles: 10,
        maxVehicles: 13,
        colorCount: 4,
        bayCount: 4,
        targetFailRate: 0.5,
        playouts: 150,
        maxAttempts: 60,
      ),
    ];
    for (final spec in specs) {
      for (final seed in [3, 4, 5]) {
        final generated = generateJamLevel(spec, seed: seed);
        final level = generated.level;
        final reason = '${spec.id} seed $seed';

        // Re-validates through the codec round trip.
        final decoded = JamLevelCodec.decodeLevel(
          JamLevelCodec.encodeLevel(level),
        );
        expect(decoded.vehicles, level.vehicles, reason: reason);

        expect(level.width, spec.width, reason: reason);
        expect(level.height, spec.height, reason: reason);
        expect(level.bayCount, spec.bayCount, reason: reason);
        expect(
          level.vehicles.length,
          inInclusiveRange(spec.minVehicles, spec.maxVehicles),
          reason: reason,
        );
        expect(generated.colorCount, spec.colorCount, reason: reason);
        expect(
          generated.occupancy,
          inInclusiveRange(spec.minOccupancy, spec.maxOccupancy),
          reason: reason,
        );
        final rules = JamRules(level);
        expect(
          rules.legalTaps(rules.initialState()).length,
          greaterThanOrEqualTo(spec.minInitialTaps),
          reason: reason,
        );
        expect(generated.failRate, greaterThan(0), reason: reason);
        expect(
          jamPlayoutFailRate(level, playouts: spec.playouts),
          generated.failRate,
          reason: reason,
        );

        // The planned order wins under the real rules.
        var state = rules.initialState();
        for (final id in generated.plannedOrder) {
          final result = rules.tap(state, id);
          expect(result.moved, isTrue, reason: '$reason tap $id');
          state = result.state;
        }
        expect(state.status, JamStatus.won, reason: reason);

        expect(solveJam(level), isA<Solvable>(), reason: reason);
      }
    }
  });

  test('playout fail rate matches analyzeJam', () {
    final level = generateJamLevel(_small, seed: 9).level;
    expect(
      jamPlayoutFailRate(level, playouts: 200, seed: 3),
      analyzeJam(level, playouts: 200, seed: 3).failRate,
    );
  });

  test('impossible specs throw', () {
    expect(
      () => generateJamLevel(
        const JamGeneratorSpec(
          id: 'too-dense',
          width: 3,
          height: 3,
          minVehicles: 9,
          maxVehicles: 9,
          colorCount: 3,
          bayCount: 3,
          maxAttempts: 5,
        ),
        seed: 1,
      ),
      throwsA(isA<JamGenerationException>()),
    );
  });
}
