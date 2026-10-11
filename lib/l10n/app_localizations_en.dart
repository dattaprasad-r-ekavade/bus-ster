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
  String get settingsCouldNotBeSaved => 'Settings could not be saved.';

  @override
  String get cancel => 'CANCEL';

  @override
  String get howToPlayTitle => 'How to play';

  @override
  String get gotIt => 'GOT IT';

  @override
  String get paused => 'PAUSED';

  @override
  String get haptics => 'Haptics';

  @override
  String get hapticsDescription => 'A light pulse on a valid move';

  @override
  String get soundEffects => 'Sound effects';

  @override
  String get soundEffectsDescription => 'Short sounds for game events';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get reduceMotionDescription => 'Skip moving bus animations';

  @override
  String get resume => 'RESUME';

  @override
  String get tryAgain => 'TRY AGAIN';

  @override
  String get undo => 'UNDO';
}
