import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name shown in the task switcher and on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Bus-ster'**
  String get appTitle;

  /// Semantics label for the startup spinner.
  ///
  /// In en, this message translates to:
  /// **'Loading levels'**
  String get loadingLevels;

  /// Shown if the bundled level pack fails to load.
  ///
  /// In en, this message translates to:
  /// **'Could not load levels.'**
  String get loadLevelsFailed;

  /// Short line under the title on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Clear the jam. Fill every bus.'**
  String get homeTagline;

  /// Progress pill on the home screen.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} cleared'**
  String homeProgress(int completed, int total);

  /// Progress pill when all levels are completed.
  ///
  /// In en, this message translates to:
  /// **'Every level cleared!'**
  String get homeAllCleared;

  /// Main button on the home screen; continues at the next uncompleted level.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get homePlay;

  /// Main home button; continues at the next uncompleted level.
  ///
  /// In en, this message translates to:
  /// **'Play level {number}'**
  String homePlayLevel(int number);

  /// Heading above the level grid.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get homeChooseLevel;

  /// Screen-reader label for a level tile.
  ///
  /// In en, this message translates to:
  /// **'Level {number}, {status, select, locked{locked} completed{completed} current{up next} other{open}}'**
  String levelTileSemantics(int number, String status);

  /// Settings screen title and pause-menu entry.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Back button label (semantics and tooltip).
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Settings toggle.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEffects;

  /// Explains the sound toggle.
  ///
  /// In en, this message translates to:
  /// **'Engine toots, boarding pops and cheers'**
  String get soundEffectsDescription;

  /// Settings toggle for haptic feedback.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get haptics;

  /// Explains the haptics toggle.
  ///
  /// In en, this message translates to:
  /// **'A light buzz when buses move or get blocked'**
  String get hapticsDescription;

  /// Settings toggle.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// Explains the reduce-motion toggle.
  ///
  /// In en, this message translates to:
  /// **'Buses jump straight to their bay, no confetti'**
  String get reduceMotionDescription;

  /// Level pill in the game HUD.
  ///
  /// In en, this message translates to:
  /// **'Level {number}'**
  String levelNumber(int number);

  /// Screen-reader label for the passengers-left counter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody waiting} =1{1 passenger waiting} other{{count} passengers waiting}}'**
  String passengersLeft(int count);

  /// Screen-reader label for a bus on the lot.
  ///
  /// In en, this message translates to:
  /// **'{color, select, red{Red} blue{Blue} green{Green} yellow{Yellow} purple{Purple} orange{Orange} other{Grey}} bus, facing {facing, select, up{up} right{right} down{down} left{left} other{ahead}}, length {length}'**
  String busSemantics(String color, String facing, int length);

  /// Tutorial bubble on level 1.
  ///
  /// In en, this message translates to:
  /// **'Tap a bus to send it to a bay!'**
  String get tutorialTapToPark;

  /// Tutorial bubble on level 2.
  ///
  /// In en, this message translates to:
  /// **'Blocked? Move the bus in front first.'**
  String get tutorialClearBlocker;

  /// Tutorial bubble on level 3.
  ///
  /// In en, this message translates to:
  /// **'Bays are limited. Pick buses the crowd needs!'**
  String get tutorialWatchTheBays;

  /// Win overlay title.
  ///
  /// In en, this message translates to:
  /// **'All aboard!'**
  String get winTitle;

  /// Win overlay body.
  ///
  /// In en, this message translates to:
  /// **'Every passenger found a seat.'**
  String get winBody;

  /// Win overlay button.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get nextLevel;

  /// Lose overlay title.
  ///
  /// In en, this message translates to:
  /// **'No room left'**
  String get loseTitle;

  /// Lose reason: bays full.
  ///
  /// In en, this message translates to:
  /// **'Every bay is full and nobody can board.'**
  String get loseBaysFull;

  /// Lose reason: no tappable bus.
  ///
  /// In en, this message translates to:
  /// **'No bus can drive out.'**
  String get loseStuck;

  /// Undo the last move.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Restart the level.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Ask for a hint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hint;

  /// Open the pause menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// Pause menu title.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// Close the pause menu.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// Pause-menu entry returning to the level select screen.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get levels;

  /// Debug-only pause-menu entry.
  ///
  /// In en, this message translates to:
  /// **'Skip level'**
  String get skipLevel;

  /// Hint toast when the position cannot be won.
  ///
  /// In en, this message translates to:
  /// **'No way out from here. Try Undo!'**
  String get hintUnsolvable;

  /// Hint toast when the solver gave up.
  ///
  /// In en, this message translates to:
  /// **'Too tricky to tell. Trust your gut!'**
  String get hintUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
