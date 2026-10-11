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
  String get routeCoral => 'Coral';

  @override
  String get routeBlue => 'Blue';

  @override
  String get routeMint => 'Mint';

  @override
  String get routeGold => 'Gold';

  @override
  String get exitLabel => 'EXIT';

  @override
  String get mechanicTagBayPressure => 'Bay pressure';

  @override
  String get mechanicTagBayTurnover => 'Bay turnover';

  @override
  String get mechanicTagBranch => 'Branch';

  @override
  String get mechanicTagBusBlocking => 'Bus blocking';

  @override
  String get mechanicTagClearPath => 'Clear path';

  @override
  String get mechanicTagDispatchOrder => 'Dispatch order';

  @override
  String get mechanicTagFifoQueue => 'Rider queue';

  @override
  String get mechanicTagLimitedBays => 'Limited bays';

  @override
  String get mechanicTagMixedRules => 'Mixed rules';

  @override
  String get mechanicTagReview => 'Review';

  @override
  String get mechanicTagRoutePlanning => 'Route planning';

  @override
  String get mechanicTagSharedExit => 'Shared exit';

  @override
  String get mechanicTagSharedRoad => 'Shared road';

  @override
  String get mechanicTagStaging => 'Staging';

  @override
  String get gameDefaultStart =>
      'Send the right buses to the gate. Follow the rider queue.';

  @override
  String get gameRouteFinished =>
      'This route is finished. Start the next depot.';

  @override
  String get gameBusAlreadyLeft => 'That bus has already left the depot.';

  @override
  String get gameBlockedRoute =>
      'Another bus is blocking every route to the gate.';

  @override
  String get gameFullBays =>
      'All departure bays are occupied. Undo a bus to make room.';

  @override
  String get gameNoClearRoute =>
      'No clear route remains. Undo a dispatch or retry the depot.';

  @override
  String get gameNoRouteTips =>
      'No route tips left. Clear a depot to earn one.';

  @override
  String get gameNoRouteFound =>
      'No route found. Undo a dispatch or retry the depot.';

  @override
  String gameRouteTip(int remaining, String route) {
    return 'Route tip ($remaining left): dispatch the $route bus.';
  }

  @override
  String get gameDispatchUndone =>
      'Last dispatch undone. Check the rider queue and road.';

  @override
  String get gameProgressRestored => 'Progress restored. Continue this depot.';

  @override
  String get gameStuckRestored =>
      'This saved route is stuck. Undo or retry the depot.';

  @override
  String get gameWonRestored =>
      'This depot is clear. Continue to the next depot.';

  @override
  String get gameDepotClear => 'Depot clear!';

  @override
  String gameRouteEnteredBay(String route) {
    return '$route entered a bay.';
  }

  @override
  String gameRouteSent(String route) {
    return '$route sent.';
  }

  @override
  String gameRidersBoarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riders boarded',
      one: '1 rider boarded',
    );
    return '$_temp0';
  }

  @override
  String gameBusesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses left the depot',
      one: '1 bus left the depot',
    );
    return '$_temp0';
  }

  @override
  String get gameNoRidersMatched => 'No riders matched; the bus waits in a bay';

  @override
  String get progressStorageUnavailable =>
      'Progress storage is unavailable on this device.';

  @override
  String get savedProgressUnreadable =>
      'Saved progress could not be read. Its files were preserved.';

  @override
  String get newerProgressPreserved =>
      'Saved progress belongs to a newer app version and was preserved.';

  @override
  String get savedProgressCouldNotResume =>
      'Saved progress could not be resumed. Start this depot again.';

  @override
  String get progressCouldNotBeSaved =>
      'Progress could not be saved on this device.';

  @override
  String get savedProgressDamaged =>
      'Saved progress was damaged. Starting a fresh depot.';

  @override
  String get savedProgressRecovered =>
      'Recovered saved progress from its last-good backup.';

  @override
  String get savedProgressAndBackupDamaged =>
      'Saved progress and its backup were damaged. Starting a fresh depot.';

  @override
  String get settingsCouldNotBeSaved => 'Settings could not be saved.';

  @override
  String get needRouteTipTitle => 'Need a Route Tip?';

  @override
  String get watchAdForRouteTip =>
      'Watch a short ad to earn 1 Route Tip. You receive it only after the ad confirms the reward; closing early may earn nothing.';

  @override
  String get notNow => 'NOT NOW';

  @override
  String get watchAd => 'WATCH AD';

  @override
  String get routeTipNotEarned =>
      'No Route Tip was earned. The game is still free to play.';

  @override
  String get leaveDepotTitle => 'Leave this depot?';

  @override
  String get leaveDepotBody =>
      'Switching depots will restart your current attempt.';

  @override
  String get cancel => 'CANCEL';

  @override
  String get switchDepot => 'SWITCH DEPOT';

  @override
  String get howToPlayTitle => 'How to play';

  @override
  String get howToPlayBody =>
      'Tap a bus when a clear road connects it to the EXIT.\n\nThe bus waits in a departure bay. Riders board from the front of the queue, in order, and only ride a matching route.\n\nA full bus leaves and opens its bay. Clear every rider to finish the depot.';

  @override
  String get gotIt => 'GOT IT';

  @override
  String get debugOverlayTooltip => 'Debug overlay';

  @override
  String debugTitle(String levelId) {
    return 'DEBUG · $levelId';
  }

  @override
  String debugStatus(String status, int moves, int queueIndex) {
    return 'Status: $status · Moves: $moves · Queue index: $queueIndex';
  }

  @override
  String get debugAuthoredSeed => 'Seed: authored level (no random seed)';

  @override
  String debugActiveBuses(String buses) {
    return 'Active buses: $buses';
  }

  @override
  String debugLegalRoutes(String routes) {
    return 'Legal routes: $routes';
  }

  @override
  String debugBlockedBuses(String buses) {
    return 'Blocked buses: $buses';
  }

  @override
  String debugSolver(String solution) {
    return 'Solver: $solution';
  }

  @override
  String get depotRoute => 'DEPOT ROUTE';

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
  String get privacyOptions => 'PRIVACY OPTIONS';

  @override
  String get resume => 'RESUME';

  @override
  String get selectDepot => 'SELECT DEPOT';

  @override
  String get unlockNextDepot => 'Clear a depot to unlock the next one.';

  @override
  String depotNumberTitle(String number, String title) {
    return 'DEPOT $number · $title';
  }

  @override
  String get nextRiders => 'NEXT RIDERS';

  @override
  String get fifoQueue => 'FIFO QUEUE';

  @override
  String get allAboard => 'All aboard!';

  @override
  String nextRiderSemantics(String route) {
    return 'Next rider, $route';
  }

  @override
  String queuedRiderSemantics(String route) {
    return 'Queued rider, $route';
  }

  @override
  String get bays => 'BAYS';

  @override
  String emptyDepartureBay(int number) {
    return 'Empty departure bay $number';
  }

  @override
  String parkedBusSemantics(String route, int loaded, int capacity) {
    return 'Parked $route bus with $loaded of $capacity riders';
  }

  @override
  String get nextDepot => 'NEXT DEPOT';

  @override
  String get tryAgain => 'TRY AGAIN';

  @override
  String get undo => 'UNDO';

  @override
  String hintCount(int count) {
    return 'HINT $count';
  }

  @override
  String routeTipCount(int count) {
    return 'ROUTE TIP · $count';
  }

  @override
  String get pauseGameTooltip => 'Pause game';

  @override
  String get selectDepotTooltip => 'Select depot';

  @override
  String get restartLevelTooltip => 'Restart level';

  @override
  String depotMoveCountCompact(String depot, int moves) {
    return 'DEPOT $depot · $moves';
  }

  @override
  String depotMoveCount(String depot, int moves) {
    return 'DEPOT $depot · $moves MOVES';
  }
}
