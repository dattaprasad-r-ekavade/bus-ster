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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bus-ster'**
  String get appTitle;

  /// No description provided for @routeCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get routeCoral;

  /// No description provided for @routeBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get routeBlue;

  /// No description provided for @routeMint.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get routeMint;

  /// No description provided for @routeGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get routeGold;

  /// No description provided for @exitLabel.
  ///
  /// In en, this message translates to:
  /// **'EXIT'**
  String get exitLabel;

  /// No description provided for @mechanicTagBayPressure.
  ///
  /// In en, this message translates to:
  /// **'Bay pressure'**
  String get mechanicTagBayPressure;

  /// No description provided for @mechanicTagBayTurnover.
  ///
  /// In en, this message translates to:
  /// **'Bay turnover'**
  String get mechanicTagBayTurnover;

  /// No description provided for @mechanicTagBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get mechanicTagBranch;

  /// No description provided for @mechanicTagBusBlocking.
  ///
  /// In en, this message translates to:
  /// **'Bus blocking'**
  String get mechanicTagBusBlocking;

  /// No description provided for @mechanicTagClearPath.
  ///
  /// In en, this message translates to:
  /// **'Clear path'**
  String get mechanicTagClearPath;

  /// No description provided for @mechanicTagDispatchOrder.
  ///
  /// In en, this message translates to:
  /// **'Dispatch order'**
  String get mechanicTagDispatchOrder;

  /// No description provided for @mechanicTagFifoQueue.
  ///
  /// In en, this message translates to:
  /// **'Rider queue'**
  String get mechanicTagFifoQueue;

  /// No description provided for @mechanicTagLimitedBays.
  ///
  /// In en, this message translates to:
  /// **'Limited bays'**
  String get mechanicTagLimitedBays;

  /// No description provided for @mechanicTagMixedRules.
  ///
  /// In en, this message translates to:
  /// **'Mixed rules'**
  String get mechanicTagMixedRules;

  /// No description provided for @mechanicTagReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get mechanicTagReview;

  /// No description provided for @mechanicTagRoutePlanning.
  ///
  /// In en, this message translates to:
  /// **'Route planning'**
  String get mechanicTagRoutePlanning;

  /// No description provided for @mechanicTagSharedExit.
  ///
  /// In en, this message translates to:
  /// **'Shared exit'**
  String get mechanicTagSharedExit;

  /// No description provided for @mechanicTagSharedRoad.
  ///
  /// In en, this message translates to:
  /// **'Shared road'**
  String get mechanicTagSharedRoad;

  /// No description provided for @mechanicTagStaging.
  ///
  /// In en, this message translates to:
  /// **'Staging'**
  String get mechanicTagStaging;

  /// No description provided for @gameDefaultStart.
  ///
  /// In en, this message translates to:
  /// **'Send the right buses to the gate. Follow the rider queue.'**
  String get gameDefaultStart;

  /// No description provided for @gameRouteFinished.
  ///
  /// In en, this message translates to:
  /// **'This route is finished. Start the next depot.'**
  String get gameRouteFinished;

  /// No description provided for @gameBusAlreadyLeft.
  ///
  /// In en, this message translates to:
  /// **'That bus has already left the depot.'**
  String get gameBusAlreadyLeft;

  /// No description provided for @gameBlockedRoute.
  ///
  /// In en, this message translates to:
  /// **'Another bus is blocking every route to the gate.'**
  String get gameBlockedRoute;

  /// No description provided for @gameFullBays.
  ///
  /// In en, this message translates to:
  /// **'All departure bays are occupied. Undo a bus to make room.'**
  String get gameFullBays;

  /// No description provided for @gameNoClearRoute.
  ///
  /// In en, this message translates to:
  /// **'No clear route remains. Undo a dispatch or retry the depot.'**
  String get gameNoClearRoute;

  /// No description provided for @gameNoRouteTips.
  ///
  /// In en, this message translates to:
  /// **'No route tips left. Clear a depot to earn one.'**
  String get gameNoRouteTips;

  /// No description provided for @gameNoRouteFound.
  ///
  /// In en, this message translates to:
  /// **'No route found. Undo a dispatch or retry the depot.'**
  String get gameNoRouteFound;

  /// No description provided for @gameRouteTip.
  ///
  /// In en, this message translates to:
  /// **'Route tip ({remaining} left): dispatch the {route} bus.'**
  String gameRouteTip(int remaining, String route);

  /// No description provided for @gameDispatchUndone.
  ///
  /// In en, this message translates to:
  /// **'Last dispatch undone. Check the rider queue and road.'**
  String get gameDispatchUndone;

  /// No description provided for @gameProgressRestored.
  ///
  /// In en, this message translates to:
  /// **'Progress restored. Continue this depot.'**
  String get gameProgressRestored;

  /// No description provided for @gameStuckRestored.
  ///
  /// In en, this message translates to:
  /// **'This saved route is stuck. Undo or retry the depot.'**
  String get gameStuckRestored;

  /// No description provided for @gameWonRestored.
  ///
  /// In en, this message translates to:
  /// **'This depot is clear. Continue to the next depot.'**
  String get gameWonRestored;

  /// No description provided for @gameDepotClear.
  ///
  /// In en, this message translates to:
  /// **'Depot clear!'**
  String get gameDepotClear;

  /// No description provided for @gameRouteEnteredBay.
  ///
  /// In en, this message translates to:
  /// **'{route} entered a bay.'**
  String gameRouteEnteredBay(String route);

  /// No description provided for @gameRouteSent.
  ///
  /// In en, this message translates to:
  /// **'{route} sent.'**
  String gameRouteSent(String route);

  /// No description provided for @gameRidersBoarded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rider boarded} other{{count} riders boarded}}'**
  String gameRidersBoarded(int count);

  /// No description provided for @gameBusesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bus left the depot} other{{count} buses left the depot}}'**
  String gameBusesLeft(int count);

  /// No description provided for @gameNoRidersMatched.
  ///
  /// In en, this message translates to:
  /// **'No riders matched; the bus waits in a bay'**
  String get gameNoRidersMatched;

  /// No description provided for @progressStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Progress storage is unavailable on this device.'**
  String get progressStorageUnavailable;

  /// No description provided for @savedProgressUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Saved progress could not be read. Its files were preserved.'**
  String get savedProgressUnreadable;

  /// No description provided for @newerProgressPreserved.
  ///
  /// In en, this message translates to:
  /// **'Saved progress belongs to a newer app version and was preserved.'**
  String get newerProgressPreserved;

  /// No description provided for @savedProgressCouldNotResume.
  ///
  /// In en, this message translates to:
  /// **'Saved progress could not be resumed. Start this depot again.'**
  String get savedProgressCouldNotResume;

  /// No description provided for @progressCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'Progress could not be saved on this device.'**
  String get progressCouldNotBeSaved;

  /// No description provided for @savedProgressDamaged.
  ///
  /// In en, this message translates to:
  /// **'Saved progress was damaged. Starting a fresh depot.'**
  String get savedProgressDamaged;

  /// No description provided for @savedProgressRecovered.
  ///
  /// In en, this message translates to:
  /// **'Recovered saved progress from its last-good backup.'**
  String get savedProgressRecovered;

  /// No description provided for @savedProgressAndBackupDamaged.
  ///
  /// In en, this message translates to:
  /// **'Saved progress and its backup were damaged. Starting a fresh depot.'**
  String get savedProgressAndBackupDamaged;

  /// No description provided for @settingsCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be saved.'**
  String get settingsCouldNotBeSaved;

  /// No description provided for @needRouteTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Need a Route Tip?'**
  String get needRouteTipTitle;

  /// No description provided for @watchAdForRouteTip.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad to earn 1 Route Tip. You receive it only after the ad confirms the reward; closing early may earn nothing.'**
  String get watchAdForRouteTip;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'NOT NOW'**
  String get notNow;

  /// No description provided for @watchAd.
  ///
  /// In en, this message translates to:
  /// **'WATCH AD'**
  String get watchAd;

  /// No description provided for @routeTipNotEarned.
  ///
  /// In en, this message translates to:
  /// **'No Route Tip was earned. The game is still free to play.'**
  String get routeTipNotEarned;

  /// No description provided for @leaveDepotTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this depot?'**
  String get leaveDepotTitle;

  /// No description provided for @leaveDepotBody.
  ///
  /// In en, this message translates to:
  /// **'Switching depots will restart your current attempt.'**
  String get leaveDepotBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancel;

  /// No description provided for @switchDepot.
  ///
  /// In en, this message translates to:
  /// **'SWITCH DEPOT'**
  String get switchDepot;

  /// No description provided for @howToPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlayTitle;

  /// No description provided for @howToPlayBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a bus when a clear road connects it to the EXIT.\n\nThe bus waits in a departure bay. Riders board from the front of the queue, in order, and only ride a matching route.\n\nA full bus leaves and opens its bay. Clear every rider to finish the depot.'**
  String get howToPlayBody;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get gotIt;

  /// No description provided for @debugOverlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Debug overlay'**
  String get debugOverlayTooltip;

  /// No description provided for @debugTitle.
  ///
  /// In en, this message translates to:
  /// **'DEBUG · {levelId}'**
  String debugTitle(String levelId);

  /// No description provided for @debugStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status} · Moves: {moves} · Queue index: {queueIndex}'**
  String debugStatus(String status, int moves, int queueIndex);

  /// No description provided for @debugAuthoredSeed.
  ///
  /// In en, this message translates to:
  /// **'Seed: authored level (no random seed)'**
  String get debugAuthoredSeed;

  /// No description provided for @debugActiveBuses.
  ///
  /// In en, this message translates to:
  /// **'Active buses: {buses}'**
  String debugActiveBuses(String buses);

  /// No description provided for @debugLegalRoutes.
  ///
  /// In en, this message translates to:
  /// **'Legal routes: {routes}'**
  String debugLegalRoutes(String routes);

  /// No description provided for @debugBlockedBuses.
  ///
  /// In en, this message translates to:
  /// **'Blocked buses: {buses}'**
  String debugBlockedBuses(String buses);

  /// No description provided for @debugSolver.
  ///
  /// In en, this message translates to:
  /// **'Solver: {solution}'**
  String debugSolver(String solution);

  /// No description provided for @depotRoute.
  ///
  /// In en, this message translates to:
  /// **'DEPOT ROUTE'**
  String get depotRoute;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get paused;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @hapticsDescription.
  ///
  /// In en, this message translates to:
  /// **'A light pulse on a valid move'**
  String get hapticsDescription;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEffects;

  /// No description provided for @soundEffectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Short sounds for game events'**
  String get soundEffectsDescription;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// No description provided for @reduceMotionDescription.
  ///
  /// In en, this message translates to:
  /// **'Skip moving bus animations'**
  String get reduceMotionDescription;

  /// No description provided for @privacyOptions.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY OPTIONS'**
  String get privacyOptions;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get resume;

  /// No description provided for @selectDepot.
  ///
  /// In en, this message translates to:
  /// **'SELECT DEPOT'**
  String get selectDepot;

  /// No description provided for @unlockNextDepot.
  ///
  /// In en, this message translates to:
  /// **'Clear a depot to unlock the next one.'**
  String get unlockNextDepot;

  /// No description provided for @depotNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'DEPOT {number} · {title}'**
  String depotNumberTitle(String number, String title);

  /// No description provided for @nextRiders.
  ///
  /// In en, this message translates to:
  /// **'NEXT RIDERS'**
  String get nextRiders;

  /// No description provided for @fifoQueue.
  ///
  /// In en, this message translates to:
  /// **'FIFO QUEUE'**
  String get fifoQueue;

  /// No description provided for @allAboard.
  ///
  /// In en, this message translates to:
  /// **'All aboard!'**
  String get allAboard;

  /// No description provided for @nextRiderSemantics.
  ///
  /// In en, this message translates to:
  /// **'Next rider, {route}'**
  String nextRiderSemantics(String route);

  /// No description provided for @queuedRiderSemantics.
  ///
  /// In en, this message translates to:
  /// **'Queued rider, {route}'**
  String queuedRiderSemantics(String route);

  /// No description provided for @bays.
  ///
  /// In en, this message translates to:
  /// **'BAYS'**
  String get bays;

  /// No description provided for @emptyDepartureBay.
  ///
  /// In en, this message translates to:
  /// **'Empty departure bay {number}'**
  String emptyDepartureBay(int number);

  /// No description provided for @parkedBusSemantics.
  ///
  /// In en, this message translates to:
  /// **'Parked {route} bus with {loaded} of {capacity} riders'**
  String parkedBusSemantics(String route, int loaded, int capacity);

  /// No description provided for @nextDepot.
  ///
  /// In en, this message translates to:
  /// **'NEXT DEPOT'**
  String get nextDepot;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get tryAgain;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'UNDO'**
  String get undo;

  /// No description provided for @hintCount.
  ///
  /// In en, this message translates to:
  /// **'HINT {count}'**
  String hintCount(int count);

  /// No description provided for @routeTipCount.
  ///
  /// In en, this message translates to:
  /// **'ROUTE TIP · {count}'**
  String routeTipCount(int count);

  /// No description provided for @pauseGameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause game'**
  String get pauseGameTooltip;

  /// No description provided for @selectDepotTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select depot'**
  String get selectDepotTooltip;

  /// No description provided for @restartLevelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Restart level'**
  String get restartLevelTooltip;

  /// No description provided for @depotMoveCountCompact.
  ///
  /// In en, this message translates to:
  /// **'DEPOT {depot} · {moves}'**
  String depotMoveCountCompact(String depot, int moves);

  /// No description provided for @depotMoveCount.
  ///
  /// In en, this message translates to:
  /// **'DEPOT {depot} · {moves} MOVES'**
  String depotMoveCount(String depot, int moves);
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
