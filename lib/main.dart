import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game/game_audio.dart';
import 'jam/ui/jam_level_loader.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BussterApp());
}

class BussterApp extends StatelessWidget {
  const BussterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F4E8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF1BE4E),
          brightness: Brightness.light,
          surface: const Color(0xFFFFFCF1),
        ),
        useMaterial3: true,
      ),
      home: JamLevelLoader(audioFactory: AudioplayersGameAudio.new),
    );
  }
}
