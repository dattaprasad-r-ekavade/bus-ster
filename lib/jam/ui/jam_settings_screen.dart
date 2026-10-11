// Settings: sound, vibration and reduced motion. Changes apply and persist
// immediately through [JamAppController].
import 'package:flutter/material.dart';

import '../../game/game_settings.dart';
import '../jam_app_controller.dart';
import '../jam_model.dart';
import 'jam_hud.dart';
import 'jam_strings.dart';
import 'jam_theme.dart';

class JamSettingsScreen extends StatelessWidget {
  const JamSettingsScreen({super.key, required this.controller});

  final JamAppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: JamPalette.plaza,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final s = controller.settings;
            void update(GameSettings next) => controller.updateSettings(next);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    JamRoundButton(
                      key: const ValueKey('settings-back'),
                      icon: Icons.arrow_back_rounded,
                      label: l10n.back,
                      size: 44,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.settingsTitle,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: JamPalette.hud,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ToggleCard(
                  switchKey: const ValueKey('settings-sound'),
                  icon: s.soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  badge: JamPalette.of(JamColor.orange).base,
                  title: l10n.soundEffects,
                  description: l10n.soundEffectsDescription,
                  value: s.soundEnabled,
                  onChanged: (v) =>
                      update(controller.settings.copyWith(soundEnabled: v)),
                ),
                const SizedBox(height: 14),
                _ToggleCard(
                  switchKey: const ValueKey('settings-haptics'),
                  icon: Icons.vibration_rounded,
                  badge: JamPalette.of(JamColor.blue).base,
                  title: l10n.haptics,
                  description: l10n.hapticsDescription,
                  value: s.hapticsEnabled,
                  onChanged: (v) =>
                      update(controller.settings.copyWith(hapticsEnabled: v)),
                ),
                const SizedBox(height: 14),
                _ToggleCard(
                  switchKey: const ValueKey('settings-reduce-motion'),
                  icon: Icons.slow_motion_video_rounded,
                  badge: JamPalette.of(JamColor.purple).base,
                  title: l10n.reduceMotion,
                  description: l10n.reduceMotionDescription,
                  value: s.reduceMotion,
                  onChanged: (v) =>
                      update(controller.settings.copyWith(reduceMotion: v)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.switchKey,
    required this.icon,
    required this.badge,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final Color badge;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: JamPalette.hud, width: 2.5),
            boxShadow: const [
              BoxShadow(color: JamPalette.hud, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: value ? badge : const Color(0xFFC9CEDA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: JamPalette.hud, width: 2),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: JamPalette.hud,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5A6378),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                key: switchKey,
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF2EC05E),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFC9CEDA),
                trackOutlineColor: const WidgetStatePropertyAll(JamPalette.hud),
                trackOutlineWidth: const WidgetStatePropertyAll(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
