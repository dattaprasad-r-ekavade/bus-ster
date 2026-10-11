// Home / level select: a sunny hero with the title, a grid of level tiles
// (locked / open / up next / completed) and a big Play button that continues
// at the next uncompleted level.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../jam_app_controller.dart';
import '../jam_model.dart';
import 'jam_hud.dart';
import 'jam_overlays.dart';
import 'jam_strings.dart';
import 'jam_theme.dart';

enum JamTileStatus { locked, open, current, completed }

class JamHomeScreen extends StatefulWidget {
  const JamHomeScreen({
    super.key,
    required this.controller,
    required this.onPlay,
    required this.onOpenSettings,
  });

  final JamAppController controller;
  final ValueChanged<int> onPlay;
  final VoidCallback onOpenSettings;

  @override
  State<JamHomeScreen> createState() => _JamHomeScreenState();
}

class _JamHomeScreenState extends State<JamHomeScreen> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  JamTileStatus _status(int i) {
    final c = widget.controller;
    if (c.isCompleted(i)) return JamTileStatus.completed;
    if (!c.isUnlocked(i)) return JamTileStatus.locked;
    return i == c.nextLevelIndex ? JamTileStatus.current : JamTileStatus.open;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: JamPalette.plaza,
        body: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            final next = c.nextLevelIndex;
            return Column(
              children: [
                _Hero(onOpenSettings: widget.onOpenSettings),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.homeChooseLevel,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: JamPalette.hud,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              key: const ValueKey('home-progress'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: JamPalette.hud,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: Color(0xFFE6A800),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    c.allCompleted
                                        ? l10n.homeAllCleared
                                        : l10n.homeProgress(
                                            c.completedCount,
                                            c.levels.length,
                                          ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: JamPalette.hud,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _grid(context, next)),
                Container(
                  decoration: const BoxDecoration(
                    color: JamPalette.plazaTile,
                    border: Border(
                      top: BorderSide(color: JamPalette.plazaEdge, width: 2),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 4),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: JamChunkyButton(
                        key: const ValueKey('home-play'),
                        label: l10n.homePlayLevel(next + 1),
                        icon: Icons.play_arrow_rounded,
                        color: const Color(0xFF2EC05E),
                        height: 64,
                        fontSize: 24,
                        onTap: () => widget.onPlay(next),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, int next) {
    final count = widget.controller.levels.length;
    return LayoutBuilder(
      builder: (context, box) {
        const pad = 16.0;
        const gap = 10.0;
        final columns = box.maxWidth >= 560 ? 7 : 5;
        final tile = (box.maxWidth - pad * 2 - gap * (columns - 1)) / columns;
        final row = tile + gap;
        _scroll ??= ScrollController(
          initialScrollOffset: math.max(
            0,
            (next ~/ columns) * row - (box.maxHeight - row) / 2,
          ),
        );
        return GridView.builder(
          key: const ValueKey('home-grid'),
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(pad, 6, pad, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
          ),
          itemCount: count,
          itemBuilder: (context, i) {
            final status = _status(i);
            return _LevelTile(
              key: ValueKey('home-level-$i'),
              number: i + 1,
              status: status,
              onTap: status == JamTileStatus.locked
                  ? null
                  : () => widget.onPlay(i),
            );
          },
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).height < 640;
    return CustomPaint(
      painter: const _HeroPainter(),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 12, compact ? 30 : 40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _BusBadge(),
                          const SizedBox(width: 12),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.appTitle,
                                key: const ValueKey('home-title'),
                                style: TextStyle(
                                  fontSize: compact ? 38 : 46,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                  height: 1,
                                  shadows: const [
                                    Shadow(
                                      color: JamPalette.hud,
                                      offset: Offset(0, 4),
                                    ),
                                    Shadow(
                                      color: JamPalette.hud,
                                      offset: Offset(2, 0),
                                    ),
                                    Shadow(
                                      color: JamPalette.hud,
                                      offset: Offset(-2, 0),
                                    ),
                                    Shadow(
                                      color: JamPalette.hud,
                                      offset: Offset(0, -2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x33000000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l10n.homeTagline,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              JamRoundButton(
                key: const ValueKey('home-settings'),
                icon: Icons.settings_rounded,
                label: l10n.settingsTitle,
                size: 46,
                onTap: onOpenSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusBadge extends StatelessWidget {
  const _BusBadge();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -0.08,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: JamPalette.of(JamColor.yellow).base,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: JamPalette.hud, width: 3),
            boxShadow: const [
              BoxShadow(color: JamPalette.hud, offset: Offset(0, 4)),
            ],
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            size: 34,
            color: JamPalette.hud,
          ),
        ),
      ),
    );
  }
}

/// Grass field with bushes and a road along the bottom edge.
class _HeroPainter extends CustomPainter {
  const _HeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const roadH = 22.0;
    final grass = Rect.fromLTWH(0, 0, size.width, size.height - roadH);
    canvas.drawRect(grass, Paint()..color = JamPalette.grass);
    // Mown stripes.
    final stripe = Paint()
      ..color = JamPalette.grassLight.withValues(alpha: 0.5);
    for (var x = -size.height; x < size.width; x += 56) {
      final path = Path()
        ..moveTo(x, grass.bottom)
        ..lineTo(x + 26, grass.bottom)
        ..lineTo(x + 26 + grass.height, 0)
        ..lineTo(x + grass.height, 0)
        ..close();
      canvas.drawPath(path, stripe);
    }
    // Bushes along the kerb.
    final bush = Paint()..color = JamPalette.bush;
    final bushLight = Paint()..color = JamPalette.bushLight;
    final rnd = math.Random(7);
    for (var x = 8.0; x < size.width; x += 38 + rnd.nextDouble() * 30) {
      final r = 9 + rnd.nextDouble() * 6;
      final c = Offset(x, grass.bottom - 4);
      canvas.drawCircle(c, r, bush);
      canvas.drawCircle(c + Offset(-r * 0.25, -r * 0.3), r * 0.55, bushLight);
    }
    // Kerb and road.
    canvas.drawRect(
      Rect.fromLTWH(0, grass.bottom - 3, size.width, 5),
      Paint()..color = JamPalette.kerb,
    );
    final road = Rect.fromLTWH(0, grass.bottom + 2, size.width, roadH - 2);
    canvas.drawRect(road, Paint()..color = JamPalette.road);
    final dash = Paint()..color = JamPalette.roadDash;
    for (var x = 6.0; x < size.width; x += 30) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, road.center.dy - 1.5, 16, 3),
          const Radius.circular(1.5),
        ),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_HeroPainter oldDelegate) => false;
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    super.key,
    required this.number,
    required this.status,
    required this.onTap,
  });

  final int number;
  final JamTileStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = status == JamTileStatus.locked;
    final current = status == JamTileStatus.current;
    final Color fill;
    final Color text;
    switch (status) {
      case JamTileStatus.completed:
        fill = JamPalette.of(JamColor.green).base;
        text = Colors.white;
      case JamTileStatus.current:
        fill = JamPalette.accent;
        text = JamPalette.hud;
      case JamTileStatus.open:
        fill = Colors.white;
        text = JamPalette.hud;
      case JamTileStatus.locked:
        fill = const Color(0xFFEBDDBE);
        text = const Color(0xFFB79A66);
    }
    return Semantics(
      button: !locked,
      enabled: !locked,
      label: l10n.levelTileSemantics(number, status.name),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, box) {
            final s = box.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(s * 0.26),
                      border: Border.all(
                        color: locked ? JamPalette.plazaEdge : JamPalette.hud,
                        width: current ? 3.5 : 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: locked ? JamPalette.plazaEdge : JamPalette.hud,
                          offset: Offset(0, locked ? 2 : 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: locked
                        ? Icon(Icons.lock_rounded, color: text, size: s * 0.38)
                        : Text(
                            '$number',
                            style: TextStyle(
                              fontSize: s * 0.4,
                              fontWeight: FontWeight.w900,
                              color: text,
                              shadows: status == JamTileStatus.completed
                                  ? const [
                                      Shadow(
                                        color: Color(0x55000000),
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                  ),
                ),
                if (status == JamTileStatus.completed)
                  Positioned(
                    right: -4,
                    top: -5,
                    child: _Badge(
                      size: s * 0.36,
                      color: Colors.white,
                      icon: Icons.check_rounded,
                      iconColor: const Color(0xFF2EC05E),
                    ),
                  ),
                if (current)
                  Positioned(
                    right: -4,
                    top: -5,
                    child: _Badge(
                      size: s * 0.36,
                      color: const Color(0xFF2EC05E),
                      icon: Icons.play_arrow_rounded,
                      iconColor: Colors.white,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.size,
    required this.color,
    required this.icon,
    required this.iconColor,
  });

  final double size;
  final Color color;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: JamPalette.hud, width: 2),
      ),
      child: Icon(icon, size: size * 0.72, color: iconColor),
    );
  }
}
