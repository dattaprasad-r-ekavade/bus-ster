// JSON level schema v2 for Bus Jam. Pure Dart.
//
// {
//   "schema": 2,
//   "levels": [
//     {
//       "id": "tutorial-1",
//       "width": 4, "height": 5, "bays": 3,
//       "hint": "tutorial.tap",                    // optional text key
//       "vehicles": [
//         // x, y = nose (head) cell; body extends backwards from it.
//         // capacity optional, defaults to 2 x length.
//         {"id": "r1", "color": "red", "facing": "up", "x": 0, "y": 1,
//          "length": 2, "capacity": 4}
//       ],
//       // Front of the queue first: [colour, count] groups.
//       "passengers": [["red", 4], ["blue", 2], ["red", 2]]
//     }
//   ]
// }
import 'dart:convert';

import 'jam_model.dart';

/// Malformed level JSON. [levelId] names the offending level when known.
class JamLevelFormatException implements Exception {
  const JamLevelFormatException(this.message, {this.levelId});

  final String message;
  final String? levelId;

  @override
  String toString() => levelId == null
      ? 'JamLevelFormatException: $message'
      : 'JamLevelFormatException: level "$levelId": $message';
}

/// Encodes and decodes schema-v2 level bundles.
abstract final class JamLevelCodec {
  static const int schemaVersion = 2;

  /// Decodes a bundle from JSON text.
  static List<JamLevel> decodeBundle(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      throw JamLevelFormatException('invalid JSON: ${e.message}');
    }
    return decodeBundleJson(json);
  }

  /// Decodes an already-parsed bundle.
  static List<JamLevel> decodeBundleJson(Object? json) {
    if (json is! Map) {
      throw const JamLevelFormatException('bundle must be a JSON object');
    }
    final schema = json['schema'];
    if (schema != schemaVersion) {
      throw JamLevelFormatException(
        'unsupported schema $schema (expected $schemaVersion)',
      );
    }
    final levels = json['levels'];
    if (levels is! List) {
      throw const JamLevelFormatException('"levels" must be a list');
    }
    final seen = <String>{};
    final decoded = <JamLevel>[];
    for (var i = 0; i < levels.length; i++) {
      final level = decodeLevel(levels[i], indexHint: i);
      if (!seen.add(level.id)) {
        throw JamLevelFormatException('duplicate level id', levelId: level.id);
      }
      decoded.add(level);
    }
    return decoded;
  }

  /// Decodes one level object. Validation failures are rethrown as
  /// [JamLevelFormatException] naming the level.
  static JamLevel decodeLevel(Object? json, {int? indexHint}) {
    final fallbackId = indexHint == null ? null : '#$indexHint';
    if (json is! Map) {
      throw JamLevelFormatException(
        'level must be a JSON object',
        levelId: fallbackId,
      );
    }
    final rawId = json['id'];
    final id = rawId is String && rawId.isNotEmpty ? rawId : fallbackId;
    Never fail(String message) =>
        throw JamLevelFormatException(message, levelId: id);
    if (rawId is! String || rawId.isEmpty) fail('"id" must be a string');

    int intField(Map map, String key, String where) {
      final value = map[key];
      if (value is int) return value;
      fail('$where"$key" must be an integer');
    }

    T enumField<T extends Enum>(
      Map map,
      String key,
      List<T> values,
      String where,
    ) {
      final value = map[key];
      for (final v in values) {
        if (v.name == value) return v;
      }
      fail(
        '$where"$key" must be one of ${values.map((v) => v.name).join('/')}'
        ', got $value',
      );
    }

    final width = intField(json, 'width', '');
    final height = intField(json, 'height', '');
    final bays = intField(json, 'bays', '');
    final hint = json['hint'];
    if (hint != null && hint is! String) fail('"hint" must be a string');

    final rawVehicles = json['vehicles'];
    if (rawVehicles is! List) fail('"vehicles" must be a list');
    final vehicles = <JamVehicle>[];
    for (var i = 0; i < rawVehicles.length; i++) {
      final raw = rawVehicles[i];
      if (raw is! Map) fail('vehicle #$i must be an object');
      final vid = raw['id'];
      if (vid is! String) fail('vehicle #$i "id" must be a string');
      final where = 'vehicle "$vid" ';
      final capacity = raw['capacity'];
      if (capacity != null && capacity is! int) {
        fail('$where"capacity" must be an integer');
      }
      vehicles.add(
        JamVehicle(
          id: vid,
          color: enumField(raw, 'color', JamColor.values, where),
          facing: enumField(raw, 'facing', JamFacing.values, where),
          head: JamCell(intField(raw, 'x', where), intField(raw, 'y', where)),
          length: intField(raw, 'length', where),
          capacity: capacity as int?,
        ),
      );
    }

    final rawPassengers = json['passengers'];
    if (rawPassengers is! List) {
      fail('"passengers" must be a list of [colour, count] groups');
    }
    final passengers = <JamColor>[];
    for (var i = 0; i < rawPassengers.length; i++) {
      final group = rawPassengers[i];
      if (group is! List || group.length != 2 || group[1] is! int) {
        fail('passenger group #$i must be [colour, count]');
      }
      final color = JamColor.values.where((c) => c.name == group[0]);
      if (color.isEmpty) {
        fail('passenger group #$i has unknown colour ${group[0]}');
      }
      final count = group[1] as int;
      if (count < 1) fail('passenger group #$i count must be at least 1');
      passengers.addAll(List.filled(count, color.first));
    }

    try {
      return JamLevel(
        id: rawId,
        width: width,
        height: height,
        bayCount: bays,
        vehicles: vehicles,
        passengers: passengers,
        hint: hint as String?,
      );
    } on JamLevelValidationException catch (e) {
      throw JamLevelFormatException(e.errors.join('; '), levelId: rawId);
    }
  }

  /// Groups consecutive same-colour passengers into `[colour, count]` pairs.
  static List<List<Object>> encodePassengers(List<JamColor> passengers) {
    final groups = <List<Object>>[];
    for (final c in passengers) {
      if (groups.isNotEmpty && groups.last[0] == c.name) {
        groups.last[1] = (groups.last[1] as int) + 1;
      } else {
        groups.add([c.name, 1]);
      }
    }
    return groups;
  }

  static Map<String, Object?> encodeLevel(JamLevel level) => {
    'id': level.id,
    'width': level.width,
    'height': level.height,
    'bays': level.bayCount,
    if (level.hint != null) 'hint': level.hint,
    'vehicles': [
      for (final v in level.vehicles)
        {
          'id': v.id,
          'color': v.color.name,
          'facing': v.facing.name,
          'x': v.head.x,
          'y': v.head.y,
          'length': v.length,
          if (!v.hasDefaultCapacity) 'capacity': v.capacity,
        },
    ],
    'passengers': encodePassengers(level.passengers),
  };

  static Map<String, Object?> encodeBundleJson(List<JamLevel> levels) => {
    'schema': schemaVersion,
    'levels': [for (final l in levels) encodeLevel(l)],
  };

  static String encodeBundle(List<JamLevel> levels, {bool pretty = true}) {
    final json = encodeBundleJson(levels);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(json)
        : jsonEncode(json);
  }
}
