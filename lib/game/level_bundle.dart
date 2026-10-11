import 'dart:convert';

import 'game_model.dart';

/// Reads and writes the versioned JSON bundle used by the Android game.
class LevelBundleCodec {
  static const schemaVersion = 2;
  static const _legacySchemaVersion = 1;

  static List<LevelSpec> decode(String source) {
    final decoded = jsonDecode(source);
    final bundle = _object(decoded, 'level bundle');
    final version = bundle['schemaVersion'];
    if (version is! int ||
        (version != schemaVersion && version != _legacySchemaVersion)) {
      throw FormatException('Unsupported level bundle schema: $version.');
    }
    final rawLevels = bundle['levels'];
    if (rawLevels is! List || rawLevels.isEmpty) {
      throw const FormatException('The level bundle must contain levels.');
    }

    final result = <LevelSpec>[];
    final levelIds = <String>{};
    for (var index = 0; index < rawLevels.length; index++) {
      final level = _decodeLevel(
        rawLevels[index],
        'levels[$index]',
        schemaVersion: version,
      );
      if (!levelIds.add(level.id)) {
        throw FormatException('Duplicate level ID "${level.id}".');
      }
      result.add(level);
    }
    return List.unmodifiable(result);
  }

  static String encode(Iterable<LevelSpec> levels) {
    final levelList = levels.toList(growable: false);
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': schemaVersion,
      'levels': [for (final level in levelList) _encodeLevel(level)],
    });
  }

  static LevelSpec _decodeLevel(
    Object? value,
    String path, {
    required int schemaVersion,
  }) {
    final json = _object(value, path);
    final id = _string(json, 'id', path, allowEmpty: false);
    final titles = _localizedText(
      json['title'],
      '$path.title',
      schemaVersion: schemaVersion,
      allowEmpty: false,
    );
    final width = _integer(json, 'width', path);
    final height = _integer(json, 'height', path);
    if (width < 1 || height < 1) {
      throw FormatException('$path width and height must be positive.');
    }

    final exit = _point(json['exit'], '$path.exit');
    final rawRoads = json['roads'];
    if (rawRoads is! List || rawRoads.isEmpty) {
      throw FormatException('$path.roads must be a non-empty array.');
    }
    final roads = <GridPoint>[];
    final roadKeys = <String>{};
    for (var index = 0; index < rawRoads.length; index++) {
      final road = _point(rawRoads[index], '$path.roads[$index]');
      _checkBounds(road, width, height, '$path.roads[$index]');
      if (!roadKeys.add('${road.x},${road.y}')) {
        throw FormatException('$path.roads contains duplicate tile $road.');
      }
      roads.add(road);
    }
    if (!roadKeys.contains('${exit.x},${exit.y}')) {
      throw FormatException('$path.exit must be part of the road network.');
    }

    final rawBuses = json['buses'];
    if (rawBuses is! List || rawBuses.isEmpty) {
      throw FormatException('$path.buses must be a non-empty array.');
    }
    final buses = <BusSpec>[];
    final busIds = <String>{};
    final busPositions = <String>{};
    for (var index = 0; index < rawBuses.length; index++) {
      final busPath = '$path.buses[$index]';
      final busJson = _object(rawBuses[index], busPath);
      final busId = _string(busJson, 'id', busPath, allowEmpty: false);
      if (!busIds.add(busId)) {
        throw FormatException('$busPath.id duplicates bus "$busId".');
      }
      final route = _route(busJson['route'], '$busPath.route');
      final position = _point(busJson['position'], '$busPath.position');
      _checkBounds(position, width, height, '$busPath.position');
      if (!roadKeys.contains('${position.x},${position.y}')) {
        throw FormatException('$busPath.position must be on a road tile.');
      }
      if (!busPositions.add('${position.x},${position.y}')) {
        throw FormatException('$path has two buses on $position.');
      }
      final capacity = _integer(busJson, 'capacity', busPath);
      if (capacity < 1) {
        throw FormatException('$busPath.capacity must be positive.');
      }
      buses.add(
        BusSpec(
          id: busId,
          route: route,
          position: position,
          capacity: capacity,
        ),
      );
    }

    final rawPassengers = json['passengerQueue'];
    if (rawPassengers is! List || rawPassengers.isEmpty) {
      throw FormatException('$path.passengerQueue must be a non-empty array.');
    }
    final passengers = [
      for (var index = 0; index < rawPassengers.length; index++)
        _route(rawPassengers[index], '$path.passengerQueue[$index]'),
    ];
    final bayCount = _integer(json, 'bayCount', path);
    if (bayCount < 1) {
      throw FormatException('$path.bayCount must be positive.');
    }

    final prompts = _localizedText(
      json['tutorialPrompt'],
      '$path.tutorialPrompt',
      schemaVersion: schemaVersion,
    );
    final rawTags = json['mechanicTags'];
    if (rawTags is! List ||
        rawTags.any((tag) => tag is! String || tag.isEmpty)) {
      throw FormatException(
        '$path.mechanicTags must contain non-empty strings.',
      );
    }
    final difficultyBand = _string(json, 'difficultyBand', path);
    const allowedBands = {'tutorial', 'easy', 'medium', 'hard', 'unrated'};
    if (!allowedBands.contains(difficultyBand)) {
      throw FormatException('$path.difficultyBand is not a supported band.');
    }
    final seed = json['seed'];
    if (seed != null && seed is! int) {
      throw FormatException('$path.seed must be an integer or null.');
    }

    return LevelSpec(
      id: id,
      title: titles['en']!,
      localizedTitles: titles,
      width: width,
      height: height,
      exit: exit,
      roads: roads,
      buses: buses,
      passengers: passengers,
      tutorialPrompt: prompts['en']!,
      localizedTutorialPrompts: prompts,
      bayCount: bayCount,
      mechanicTags: rawTags.cast<String>(),
      difficultyBand: difficultyBand,
      seed: seed as int?,
    );
  }

  static Map<String, Object?> _encodeLevel(LevelSpec level) => {
    'id': level.id,
    'title': level.localizedTitles,
    'width': level.width,
    'height': level.height,
    'exit': _encodePoint(level.exit),
    'roads': [
      for (final road in level.roads.toList()..sort(_comparePoints))
        _encodePoint(road),
    ],
    'bayCount': level.bayCount,
    'buses': [
      for (final bus in level.buses)
        {
          'id': bus.id,
          'route': bus.route.name,
          'position': _encodePoint(bus.position),
          'capacity': bus.capacity,
        },
    ],
    'passengerQueue': [for (final route in level.passengers) route.name],
    'tutorialPrompt': level.localizedTutorialPrompts,
    'mechanicTags': level.mechanicTags,
    'difficultyBand': level.difficultyBand,
    'seed': level.seed,
  };

  static Map<String, Object?> _encodePoint(GridPoint point) => {
    'x': point.x,
    'y': point.y,
  };

  static int _comparePoints(GridPoint a, GridPoint b) =>
      a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y);

  static Map<String, Object?> _object(Object? value, String path) {
    if (value is! Map) throw FormatException('$path must be an object.');
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$path contains a non-string key.');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static String _string(
    Map<String, Object?> json,
    String key,
    String path, {
    bool allowEmpty = true,
  }) {
    final value = json[key];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('$path.$key must be a string.');
    }
    return value;
  }

  static Map<String, String> _localizedText(
    Object? value,
    String path, {
    required int schemaVersion,
    bool allowEmpty = true,
  }) {
    if (schemaVersion == _legacySchemaVersion) {
      if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
        throw FormatException('$path must be a string.');
      }
      return {'en': value};
    }

    final json = _object(value, path);
    final translations = <String, String>{};
    final localePattern = RegExp(r'^[a-zA-Z]{2,8}(?:-[a-zA-Z0-9]{1,8})*$');
    for (final entry in json.entries) {
      final locale = entry.key;
      final normalizedLocale = locale.replaceAll('_', '-').toLowerCase();
      final text = entry.value;
      if (!localePattern.hasMatch(locale) ||
          text is! String ||
          (!allowEmpty && text.trim().isEmpty)) {
        throw FormatException('$path must map locale codes to strings.');
      }
      if (translations.containsKey(normalizedLocale)) {
        throw FormatException('$path contains duplicate locale "$locale".');
      }
      translations[normalizedLocale] = text;
    }
    if (!translations.containsKey('en')) {
      throw FormatException('$path must include an English fallback.');
    }
    return translations;
  }

  static int _integer(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! int) throw FormatException('$path.$key must be an integer.');
    return value;
  }

  static GridPoint _point(Object? value, String path) {
    final json = _object(value, path);
    return GridPoint(_integer(json, 'x', path), _integer(json, 'y', path));
  }

  static void _checkBounds(
    GridPoint point,
    int width,
    int height,
    String path,
  ) {
    if (point.x < 0 || point.y < 0 || point.x >= width || point.y >= height) {
      throw FormatException(
        '$path $point is outside the ${width}x$height board.',
      );
    }
  }

  static RouteKind _route(Object? value, String path) {
    if (value is String) {
      for (final route in RouteKind.values) {
        if (route.name == value) return route;
      }
    }
    throw FormatException(
      '$path must be one of: ${RouteKind.values.map((route) => route.name).join(', ')}.',
    );
  }
}
