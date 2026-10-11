// Localised copy for the Bus Jam UI. All text comes from lib/l10n/app_en.arb;
// this file only adapts model values (colours, facings, hint keys) to the
// generated [AppLocalizations] API.
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../jam_model.dart';

extension JamL10nContext on BuildContext {
  /// Localised strings; falls back to English when the widget tree has no
  /// localisation delegates (e.g. a bare widget test harness).
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('en'));
}

extension JamStrings on AppLocalizations {
  /// Tutorial bubble text for a level hint key, or null when unknown.
  String? tutorialHint(String? key) => switch (key) {
    'tutorial.tapToPark' => tutorialTapToPark,
    'tutorial.clearBlocker' => tutorialClearBlocker,
    'tutorial.watchTheBays' => tutorialWatchTheBays,
    _ => null,
  };

  String busLabel(JamVehicle v) =>
      busSemantics(v.color.name, v.facing.name, v.length);
}
