// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bus-ster';

  @override
  String get loadingLevels => 'Loading levels';

  @override
  String get loadLevelsFailed => 'Could not load levels.';

  @override
  String get homeTagline => 'Clear the jam. Fill every bus.';

  @override
  String homeProgress(int completed, int total) {
    return '$completed of $total cleared';
  }

  @override
  String get homeAllCleared => 'Every level cleared!';

  @override
  String get homePlay => 'Play';

  @override
  String homePlayLevel(int number) {
    return 'Play level $number';
  }

  @override
  String get homeChooseLevel => 'Levels';

  @override
  String levelTileSemantics(int number, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'locked': 'locked',
      'completed': 'completed',
      'current': 'up next',
      'other': 'open',
    });
    return 'Level $number, $_temp0';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get back => 'Back';

  @override
  String get soundEffects => 'Sound effects';

  @override
  String get soundEffectsDescription =>
      'Engine toots, boarding pops and cheers';

  @override
  String get haptics => 'Vibration';

  @override
  String get hapticsDescription =>
      'A light buzz when buses move or get blocked';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get reduceMotionDescription =>
      'Buses jump straight to their bay, no confetti';

  @override
  String levelNumber(int number) {
    return 'Level $number';
  }

  @override
  String passengersLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passengers waiting',
      one: '1 passenger waiting',
      zero: 'Nobody waiting',
    );
    return '$_temp0';
  }

  @override
  String busSemantics(String color, String facing, int length) {
    String _temp0 = intl.Intl.selectLogic(color, {
      'red': 'Red',
      'blue': 'Blue',
      'green': 'Green',
      'yellow': 'Yellow',
      'purple': 'Purple',
      'orange': 'Orange',
      'other': 'Grey',
    });
    String _temp1 = intl.Intl.selectLogic(facing, {
      'up': 'up',
      'right': 'right',
      'down': 'down',
      'left': 'left',
      'other': 'ahead',
    });
    return '$_temp0 bus, facing $_temp1, length $length';
  }

  @override
  String get tutorialTapToPark => 'Tap a bus to send it to a bay!';

  @override
  String get tutorialClearBlocker => 'Blocked? Move the bus in front first.';

  @override
  String get tutorialWatchTheBays =>
      'Bays are limited. Pick buses the crowd needs!';

  @override
  String get winTitle => 'All aboard!';

  @override
  String get winBody => 'Every passenger found a seat.';

  @override
  String get nextLevel => 'Next level';

  @override
  String get loseTitle => 'No room left';

  @override
  String get loseBaysFull => 'Every bay is full and nobody can board.';

  @override
  String get loseStuck => 'No bus can drive out.';

  @override
  String get undo => 'Undo';

  @override
  String get retry => 'Retry';

  @override
  String get hint => 'Hint';

  @override
  String get menu => 'Menu';

  @override
  String get paused => 'Paused';

  @override
  String get resume => 'Resume';

  @override
  String get levels => 'Levels';

  @override
  String get skipLevel => 'Skip level';

  @override
  String get hintUnsolvable => 'No way out from here. Try Undo!';

  @override
  String get hintUnknown => 'Too tricky to tell. Trust your gut!';
}
