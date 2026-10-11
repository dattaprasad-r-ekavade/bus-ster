// Slim top bar: level pill, passengers-left counter, round icon buttons.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'jam_strings.dart';
import 'jam_theme.dart';

class JamHud extends StatelessWidget {
  const JamHud({
    super.key,
    required this.levelNumber,
    required this.passengersLeft,
    required this.canUndo,
    required this.onUndo,
    required this.onRetry,
    required this.onHint,
    required this.onMenu,
  });

  static const double height = 48;

  final int levelNumber;
  final ValueListenable<int> passengersLeft;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRetry;
  final VoidCallback onHint;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 360;
        final button = narrow ? 34.0 : 40.0;
        final gap = narrow ? 4.0 : 6.0;
        return SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 6 : 10),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Pill(
                            key: const ValueKey('jam-level-pill'),
                            color: JamPalette.hud,
                            child: Text(
                              JamStrings.level(levelNumber),
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: narrow ? 14 : 16,
                              ),
                            ),
                          ),
                          SizedBox(width: gap),
                          ValueListenableBuilder<int>(
                            valueListenable: passengersLeft,
                            builder: (context, n, _) => Semantics(
                              label: JamStrings.passengersLeft(n),
                              excludeSemantics: true,
                              child: _Pill(
                                key: const ValueKey('jam-passenger-counter'),
                                color: Colors.white,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      size: narrow ? 16 : 18,
                                      color: JamPalette.hud,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$n',
                                      style: TextStyle(
                                        color: JamPalette.hud,
                                        fontWeight: FontWeight.w900,
                                        fontSize: narrow ? 14 : 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: gap),
                _RoundButton(
                  key: const ValueKey('jam-undo'),
                  icon: Icons.undo_rounded,
                  label: JamStrings.undo,
                  size: button,
                  enabled: canUndo,
                  onTap: onUndo,
                ),
                SizedBox(width: gap),
                _RoundButton(
                  key: const ValueKey('jam-retry'),
                  icon: Icons.refresh_rounded,
                  label: JamStrings.retry,
                  size: button,
                  onTap: onRetry,
                ),
                SizedBox(width: gap),
                _RoundButton(
                  key: const ValueKey('jam-hint'),
                  icon: Icons.lightbulb_rounded,
                  label: JamStrings.hintLabel,
                  size: button,
                  accent: true,
                  onTap: onHint,
                ),
                SizedBox(width: gap),
                _RoundButton(
                  key: const ValueKey('jam-menu'),
                  icon: Icons.pause_rounded,
                  label: JamStrings.menu,
                  size: button,
                  onTap: onMenu,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.size,
    required this.onTap,
    this.enabled = true,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final double size;
  final VoidCallback onTap;
  final bool enabled;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final bg = accent ? JamPalette.accent : Colors.white;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.45,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: JamPalette.hud, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), offset: Offset(0, 3)),
                ],
              ),
              child: Icon(icon, color: JamPalette.hud, size: size * 0.56),
            ),
          ),
        ),
      ),
    );
  }
}
