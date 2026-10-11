// English copy for the Bus Jam screen. Kept in one place so it can move to
// ARB localisation in the integration phase without touching widgets.
import '../jam_model.dart';

abstract final class JamStrings {
  static const Map<String, String> _hints = {
    'tutorial.tapToPark': 'Tap a bus to send it to a bay!',
    'tutorial.clearBlocker': 'Blocked? Move the bus in front first.',
    'tutorial.watchTheBays': 'Bays are limited. Pick buses the crowd needs!',
  };

  /// Tutorial bubble text for a level hint key, or null when unknown.
  static String? hint(String? key) => key == null ? null : _hints[key];

  static String colorName(JamColor c) => switch (c) {
    JamColor.red => 'Red',
    JamColor.blue => 'Blue',
    JamColor.green => 'Green',
    JamColor.yellow => 'Yellow',
    JamColor.purple => 'Purple',
    JamColor.orange => 'Orange',
  };

  static String facingName(JamFacing f) => switch (f) {
    JamFacing.up => 'up',
    JamFacing.right => 'right',
    JamFacing.down => 'down',
    JamFacing.left => 'left',
  };

  static String busLabel(JamVehicle v) =>
      '${colorName(v.color)} bus, facing ${facingName(v.facing)}, '
      'length ${v.length}';

  static String level(int number) => 'Level $number';
  static String passengersLeft(int n) => '$n passengers waiting';

  static const winTitle = 'All aboard!';
  static const winBody = 'Every passenger found a seat.';
  static const nextLevel = 'Next level';
  static const loseTitle = 'No room left';
  static const loseBaysFull = 'Every bay is full and nobody can board.';
  static const loseStuck = 'No bus can drive out.';
  static const undo = 'Undo';
  static const retry = 'Retry';
  static const hintLabel = 'Hint';
  static const menu = 'Menu';
  static const paused = 'Paused';
  static const resume = 'Resume';
  static const skipLevel = 'Skip level';
  static const hintUnsolvable = 'No way out from here. Try Undo!';
  static const hintUnknown = 'Too tricky to tell. Trust your gut!';
  static const hintThinking = 'Thinking...';
}
