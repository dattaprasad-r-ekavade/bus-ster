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
    expect(
      '${LevelBundleCodec.encode(levels)}\n',
      source.replaceAll('\r\n', '\n'),
    );
  });

  test('rejects an unknown bundle schema version', () {
    final bundle = jsonDecode(source) as Map<String, Object?>;
    bundle['schemaVersion'] = 3;

    expect(
      () => LevelBundleCodec.decode(jsonEncode(bundle)),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'reads version 1 English strings and writes localized schema version 2',
    () {
      final bundle = jsonDecode(source) as Map<String, Object?>;
      bundle['schemaVersion'] = 1;
      final legacyLevels = (bundle['levels'] as List).map((entry) {
        final level = Map<String, Object?>.from(entry as Map);
        level['title'] = (level['title'] as Map)['en'];
        level['tutorialPrompt'] = (level['tutorialPrompt'] as Map)['en'];
        return level;
      }).toList();
      bundle['levels'] = legacyLevels;

      final decoded = LevelBundleCodec.decode(jsonEncode(bundle));
      final encoded = jsonDecode(LevelBundleCodec.encode(decoded));
      expect(decoded.first.title, levels.first.title);
      expect(decoded.first.tutorialPrompt, levels.first.tutorialPrompt);
      expect(encoded['schemaVersion'], LevelBundleCodec.schemaVersion);
      expect((encoded['levels'] as List).first['title'], {
        'en': levels.first.title,
      });
    },
  );

  test(
    'level titles and prompts resolve exact, language, and English fallbacks',
    () {
      final bundle = jsonDecode(source) as Map<String, Object?>;
      final entries = (bundle['levels'] as List).toList();
      final first = Map<String, Object?>.from(entries.first as Map);
      first['title'] = {
        'en': 'English title',
        'es': 'Título',
        'es-MX': 'Título mexicano',
      };
      first['tutorialPrompt'] = {'en': 'English prompt', 'es': 'Instrucción'};
      entries[0] = first;
      bundle['levels'] = entries;

      final level = LevelBundleCodec.decode(jsonEncode(bundle)).first;
      expect(level.titleFor('es-MX'), 'Título mexicano');
      expect(level.titleFor('es-ES'), 'Título');
      expect(level.titleFor('fr-FR'), 'English title');
      expect(level.tutorialPromptFor('es-MX'), 'Instrucción');
      expect(level.tutorialPromptFor('fr-FR'), 'English prompt');
    },
  );

  test('localized content requires English fallback text', () {
    final bundle = jsonDecode(source) as Map<String, Object?>;
    final entries = (bundle['levels'] as List).toList();
    final first = Map<String, Object?>.from(entries.first as Map);
    first['title'] = {'es': 'Título'};
    entries[0] = first;
    bundle['levels'] = entries;

    expect(
      () => LevelBundleCodec.decode(jsonEncode(bundle)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('English fallback'),
        ),
      ),
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
