import 'dart:convert';

import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'jam_test_helpers.dart';

Map<String, Object?> levelJson({
  String id = 'L1',
  Object? passengers,
  List<Object?>? vehicles,
  Object? bays = 3,
}) => {
  'id': id,
  'width': 4,
  'height': 4,
  'bays': bays,
  'vehicles':
      vehicles ??
      [
        {
          'id': 'r1',
          'color': 'red',
          'facing': 'up',
          'x': 0,
          'y': 1,
          'length': 2,
        },
        {
          'id': 'b1',
          'color': 'blue',
          'facing': 'right',
          'x': 3,
          'y': 0,
          'length': 3,
          'capacity': 2,
        },
      ],
  'passengers':
      passengers ??
      [
        ['red', 2],
        ['blue', 2],
        ['red', 2],
      ],
};

String bundle(List<Object?> levels, {Object? schema = 2}) =>
    jsonEncode({'schema': schema, 'levels': levels});

Matcher formatError(String levelId, String fragment) => throwsA(
  isA<JamLevelFormatException>()
      .having((e) => e.levelId, 'levelId', levelId)
      .having((e) => e.toString(), 'toString', contains(fragment)),
);

void main() {
  test('decodes groups, head coordinates and default capacity', () {
    final levels = JamLevelCodec.decodeBundle(bundle([levelJson()]));
    expect(levels, hasLength(1));
    final level = levels.single;
    expect(level.id, 'L1');
    expect(level.bayCount, 3);
    expect(level.passengers, crowd([(red, 2), (blue, 2), (red, 2)]));
    expect(level.vehicle('r1').capacity, 4);
    expect(level.vehicle('r1').head, const JamCell(0, 1));
    expect(level.vehicle('b1').capacity, 2);
    expect(level.vehicle('b1').cells, const [
      JamCell(3, 0),
      JamCell(2, 0),
      JamCell(1, 0),
    ]);
    expect(level.hint, isNull);
  });

  test('round-trips through encode and decode', () {
    final original = JamLevel(
      id: 'rt',
      width: 6,
      height: 7,
      bayCount: 5,
      hint: 'tutorial.x',
      vehicles: [
        bus('r1', red, up, 0, 3),
        bus('b1', blue, left, 1, 0, length: 4, capacity: 3),
        bus('g1', green, down, 5, 6, length: 3),
      ],
      passengers: crowd([(red, 2), (blue, 3), (red, 2), (green, 6)]),
    );
    final text = JamLevelCodec.encodeBundle([original]);
    final decoded = JamLevelCodec.decodeBundle(text).single;
    expect(decoded.id, original.id);
    expect(decoded.width, original.width);
    expect(decoded.height, original.height);
    expect(decoded.bayCount, original.bayCount);
    expect(decoded.hint, original.hint);
    expect(decoded.vehicles, original.vehicles);
    expect(decoded.passengers, original.passengers);
    expect(JamLevelCodec.encodeBundle([decoded]), text);

    final json = JamLevelCodec.encodeLevel(original);
    expect(json['passengers'], [
      ['red', 2],
      ['blue', 3],
      ['red', 2],
      ['green', 6],
    ]);
    final vehicles = json['vehicles'] as List;
    expect((vehicles[0] as Map).containsKey('capacity'), isFalse);
    expect((vehicles[1] as Map)['capacity'], 3);
  });

  test('rejects other schema versions and malformed bundles', () {
    for (final schema in [1, 3, null, '2']) {
      expect(
        () => JamLevelCodec.decodeBundle(bundle([levelJson()], schema: schema)),
        throwsA(isA<JamLevelFormatException>()),
        reason: 'schema $schema',
      );
    }
    expect(
      () => JamLevelCodec.decodeBundle('not json'),
      throwsA(isA<JamLevelFormatException>()),
    );
    expect(
      () => JamLevelCodec.decodeBundle('[]'),
      throwsA(isA<JamLevelFormatException>()),
    );
  });

  test('validation errors name the level', () {
    expect(
      () => JamLevelCodec.decodeBundle(
        bundle([
          levelJson(
            id: 'mismatch',
            passengers: [
              ['red', 3],
              ['blue', 2],
            ],
          ),
        ]),
      ),
      formatError('mismatch', 'red: 4 seats but 3 riders'),
    );
    expect(
      () =>
          JamLevelCodec.decodeBundle(bundle([levelJson(id: 'bays', bays: 0)])),
      formatError('bays', 'bayCount 0'),
    );
  });

  test('field errors name the level and the field', () {
    expect(
      () => JamLevelCodec.decodeBundle(
        bundle([
          levelJson(
            id: 'colour',
            vehicles: [
              {
                'id': 'x',
                'color': 'pink',
                'facing': 'up',
                'x': 0,
                'y': 1,
                'length': 2,
              },
            ],
          ),
        ]),
      ),
      formatError('colour', 'vehicle "x" "color" must be one of'),
    );
    expect(
      () => JamLevelCodec.decodeBundle(
        bundle([
          levelJson(
            id: 'groups',
            passengers: [
              ['red', 4, 1],
            ],
          ),
        ]),
      ),
      formatError('groups', 'passenger group #0 must be [colour, count]'),
    );
    expect(
      () => JamLevelCodec.decodeBundle(bundle([levelJson(bays: '3')])),
      formatError('L1', '"bays" must be an integer'),
    );
    expect(
      () => JamLevelCodec.decodeBundle(bundle([levelJson(), 5])),
      formatError('#1', 'level must be a JSON object'),
    );
  });

  test('rejects duplicate level ids', () {
    expect(
      () => JamLevelCodec.decodeBundle(bundle([levelJson(), levelJson()])),
      formatError('L1', 'duplicate level id'),
    );
  });
}
