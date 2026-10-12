// Modal and transient overlays: win (with confetti), lose, pause menu,
// tutorial speech bubble and toast.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../jam_model.dart';
import 'jam_strings.dart';
import 'jam_theme.dart';

class JamWinOverlay extends StatefulWidget {
  const JamWinOverlay({
    super.key,
    required this.onNext,
    required this.reduceMotion,
  });

  final VoidCallback onNext;
  final bool reduceMotion;

  @override
  State<JamWinOverlay> createState() => _JamWinOverlayState();
}

class _JamWinOverlayState extends State<JamWinOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Scrim(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!widget.reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ConfettiPainter(_c)),
              ),
            ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = (_c.value / 0.25).clamp(0.0, 1.0);
              return Transform.scale(
                scale: 0.6 + 0.4 * easeOutBack(t),
                child: Opacity(opacity: t, child: child),
              );
            },
            child: _Card(
              key: const ValueKey('jam-win-overlay'),
              icon: Icons.emoji_events_rounded,
              iconColor: JamPalette.accent,
              title: l10n.winTitle,
              body: l10n.winBody,
              actions: [
                JamChunkyButton(
                  key: const ValueKey('jam-next'),
                  label: l10n.nextLevel,
                  color: const Color(0xFF2EC05E),
                  onTap: widget.onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JamLoseOverlay extends StatelessWidget {
  const JamLoseOverlay({
    super.key,
    required this.baysFull,
    required this.onUndo,
    required this.onRetry,
  });

  final bool baysFull;
  final VoidCallback onUndo;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Scrim(
      child: _Card(
        key: const ValueKey('jam-lose-overlay'),
        icon: Icons.no_crash_rounded,
        iconColor: const Color(0xFFEF4444),
        title: l10n.loseTitle,
        body: baysFull ? l10n.loseBaysFull : l10n.loseStuck,
        actions: [
          JamChunkyButton(
            key: const ValueKey('jam-lose-undo'),
            label: l10n.undo,
            color: const Color(0xFF2F86F0),
            onTap: onUndo,
          ),
          JamChunkyButton(
            key: const ValueKey('jam-lose-retry'),
            label: l10n.retry,
            color: const Color(0xFFFF8A1F),
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class JamPauseOverlay extends StatelessWidget {
  const JamPauseOverlay({
    super.key,
    required this.onResume,
    required this.onRetry,
    this.onLevels,
    this.onSettings,
    this.onSkip,
  });

  final VoidCallback onResume;
  final VoidCallback onRetry;

  /// Back to the level select screen; hidden when null.
  final VoidCallback? onLevels;

  /// Opens settings; hidden when null.
  final VoidCallback? onSettings;

  /// Debug-only shortcut; never shown in release builds.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = [
      if (onLevels != null)
        JamChunkyButton(
          key: const ValueKey('jam-pause-levels'),
          label: l10n.levels,
          icon: Icons.grid_view_rounded,
          color: const Color(0xFF2F86F0),
          compact: true,
          onTap: onLevels!,
        ),
      if (onSettings != null)
        JamChunkyButton(
          key: const ValueKey('jam-pause-settings'),
          label: l10n.settingsTitle,
          icon: Icons.settings_rounded,
          color: const Color(0xFF9B5DE5),
          compact: true,
          onTap: onSettings!,
        ),
    ];
    return _Scrim(
      child: _Card(
        key: const ValueKey('jam-pause-overlay'),
        icon: Icons.pause_circle_filled_rounded,
        iconColor: JamPalette.hud,
        title: l10n.paused,
        actions: [
          JamChunkyButton(
            key: const ValueKey('jam-resume'),
            label: l10n.resume,
            color: const Color(0xFF2EC05E),
            onTap: onResume,
          ),
          JamChunkyButton(
            key: const ValueKey('jam-pause-retry'),
            label: l10n.retry,
            color: const Color(0xFFFF8A1F),
            onTap: onRetry,
          ),
          if (secondary.isNotEmpty)
            Row(
              children: [
                for (var i = 0; i < secondary.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: secondary[i]),
                ],
              ],
            ),
          if (kDebugMode && onSkip != null)
            JamChunkyButton(
              key: const ValueKey('jam-skip'),
              label: l10n.skipLevel,
              color: const Color(0xFF8D96A8),
              compact: true,
              onTap: onSkip!,
            ),
        ],
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x8C1A2033),
        child: Center(child: child),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.actions,
    this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = math.min(320.0, MediaQuery.sizeOf(context).width - 40);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF3),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: JamPalette.hud, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: iconColor),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: JamPalette.hud,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A6378),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// Big toy-like pill button with a hard drop shadow.
class JamChunkyButton extends StatelessWidget {
  const JamChunkyButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.compact = false,
    this.height,
    this.fontSize,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final bool compact;
  final double? height;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final size = fontSize ?? (compact ? 17.0 : 20.0);
    const shadows = [Shadow(color: Color(0x66000000), offset: Offset(0, 2))];
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height ?? (compact ? 46 : 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: JamPalette.hud, width: 2.5),
            boxShadow: const [
              BoxShadow(color: JamPalette.hud, offset: Offset(0, 4)),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: Colors.white,
                    size: size + 2,
                    shadows: shadows,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    shadows: shadows,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;
  static final List<_Bit> _bits = _makeBits();

  static List<_Bit> _makeBits() {
    final rnd = math.Random(42);
    final colors = [
      for (final c in JamColor.values) JamPalette.of(c).base,
      Colors.white,
    ];
    return [
      for (var i = 0; i < 90; i++)
        _Bit(
          angle: -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.3,
          speed: 0.55 + rnd.nextDouble() * 0.75,
          spin: (rnd.nextDouble() - 0.5) * 18,
          size: 5 + rnd.nextDouble() * 6,
          color: colors[rnd.nextInt(colors.length)],
          circle: rnd.nextBool(),
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 1.8;
    if (t <= 0 || anim.value >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final scale = size.height;
    final paint = Paint();
    for (final b in _bits) {
      final v = Offset(math.cos(b.angle), math.sin(b.angle)) * b.speed * scale;
      final p = origin + v * t * 0.9 + Offset(0, 0.55 * scale * t * t);
      final fade = anim.value > 0.75 ? (1 - anim.value) / 0.25 : 1.0;
      paint.color = b.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(b.spin * t);
      if (b.circle) {
        canvas.drawCircle(Offset.zero, b.size * 0.45, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: b.size,
            height: b.size * 0.5,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}

class _Bit {
  const _Bit({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
    required this.circle,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
  final bool circle;
}

/// Speech bubble anchored above (or below) a point on the board.
class JamTutorialBubble extends StatelessWidget {
  const JamTutorialBubble({
    super.key,
    required this.text,
    required this.anchor,
    required this.bounds,
    required this.below,
  });

  final String text;
  final Offset anchor;
  final Size bounds;
  final bool below;

  static const TextStyle _textStyle = TextStyle(
    color: JamPalette.hud,
    fontWeight: FontWeight.w800,
    fontSize: 15,
    height: 1.2,
  );

  static double _widthIn(Size bounds) => math.min(240.0, bounds.width - 24);

  /// The rect the bubble for [text] paints in when anchored at [anchor]
  /// (its top edge when [below], its bottom edge otherwise) inside [bounds].
  static Rect rectFor({
    required String text,
    required Offset anchor,
    required bool below,
    required Size bounds,
  }) {
    final width = _widthIn(bounds);
    // Text wrapped to the bubble's inner width (padding 14 each side, border
    // 2.5 each side), plus vertical padding 10 each side and the border.
    final painter = TextPainter(
      text: TextSpan(text: text, style: _textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 28 - 5);
    final height = painter.height + 20 + 5;
    final left = (anchor.dx - width / 2).clamp(12.0, bounds.width - width - 12);
    // Above: the anchor is the bubble's bottom edge (see build).
    final top = below ? anchor.dy : anchor.dy - height;
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  Widget build(BuildContext context) {
    final width = _widthIn(bounds);
    final rect = rectFor(
      text: text,
      anchor: anchor,
      below: below,
      bounds: bounds,
    );
    final bubble = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JamPalette.hud, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), offset: Offset(0, 3)),
        ],
      ),
      child: Text(text, textAlign: TextAlign.center, style: _textStyle),
    );
    return Positioned(
      left: rect.left,
      width: width,
      top: below ? anchor.dy : null,
      bottom: below ? null : bounds.height - anchor.dy,
      child: IgnorePointer(child: Semantics(liveRegion: true, child: bubble)),
    );
  }
}

/// Small transient message pill.
class JamToast extends StatelessWidget {
  const JamToast({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        child: Container(
          key: const ValueKey('jam-toast'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: JamPalette.hud,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), offset: Offset(0, 3)),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
