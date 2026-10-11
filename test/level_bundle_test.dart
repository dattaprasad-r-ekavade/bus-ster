import 'dart:convert';
import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late List<LevelSpec> levels;

  setUpAll(() async {
    source = await File('assets/levels/levels.json').readAsString();
    levels = LevelBundleCodec.decode(source);
  });

  test('decodes the bundled schema and round-trips it deterministically', () {
    expect(levels, hasLength(10));
    expect(levels.first.difficultyBand, 'tutorial');
    expect(levels.first.mechanicTags, contains('clear-path'));
    expect('${LevelBundleCodec.encode(levels)}\n', source);
  });

  test('rejects an unknown bundle schema version', () {
    final bundle = jsonDecode(source) as Map<String, Object?>;
    bundle['schemaVersion'] = 2;

    expect(
      () => LevelBundleCodec.decode(jsonEncode(bundle)),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects duplicate level IDs', () {
    final bundle = jsonDecode(source) as Map<String, Object?>;
    final entries = (bundle['levels'] as List).toList();
    entries.add(entries.first);
    bundle['levels'] = entries;

    expect(
      () => LevelBundleCodec.decode(jsonEncode(bundle)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Duplicate level ID'),
        ),
      ),
    );
  });

  test('rejects roads outside the board', () {
    final bundle = jsonDecode(source) as Map<String, Object?>;
    final entries = (bundle['levels'] as List).toList();
    final first = Map<String, Object?>.from(entries.first as Map);
    final roads = (first['roads'] as List).toList();
    roads[0] = {'x': 5, 'y': 0};
    first['roads'] = roads;
    entries[0] = first;
    bundle['levels'] = entries;

    expect(
      () => LevelBundleCodec.decode(jsonEncode(bundle)),
      throwsA(isA<FormatException>()),
    );
  });
}
