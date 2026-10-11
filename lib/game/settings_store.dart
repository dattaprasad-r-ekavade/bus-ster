import 'package:shared_preferences/shared_preferences.dart';

import 'game_settings.dart';

/// SharedPreferences is used only for small, non-critical player preferences.
class SharedPreferencesGameSettingsStore implements GameSettingsStore {
  SharedPreferencesGameSettingsStore({SharedPreferencesAsync? preferences})
    : _providedPreferences = preferences;

  static const _hapticsKey = 'settings.hapticsEnabled';
  static const _soundKey = 'settings.soundEnabled';
  static const _reduceMotionKey = 'settings.reduceMotion';

  final SharedPreferencesAsync? _providedPreferences;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _storage =>
      _preferences ??= _providedPreferences ?? SharedPreferencesAsync();

  @override
  Future<GameSettings> load() async => GameSettings(
    hapticsEnabled: await _storage.getBool(_hapticsKey) ?? true,
    soundEnabled: await _storage.getBool(_soundKey) ?? true,
    reduceMotion: await _storage.getBool(_reduceMotionKey) ?? false,
  );

  @override
  Future<void> save(GameSettings settings) async {
    await _storage.setBool(_hapticsKey, settings.hapticsEnabled);
    await _storage.setBool(_soundKey, settings.soundEnabled);
    await _storage.setBool(_reduceMotionKey, settings.reduceMotion);
  }
}
