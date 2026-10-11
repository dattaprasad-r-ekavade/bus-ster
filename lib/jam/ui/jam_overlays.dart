// Modal and transient overlays: win (with confetti), lose, pause menu,
// tutorial speech bubble and toast.
import 'dart:math' as math;

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
              title: JamStrings.winTitle,
              body: JamStrings.winBody,
              actions: [
                _ChunkyButton(
                  key: const ValueKey('jam-next'),
                  label: JamStrings.nextLevel,
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
    return _Scrim(
      child: _Card(
        key: const ValueKey('jam-lose-overlay'),
        icon: Icons.no_crash_rounded,
        iconColor: const Color(0xFFEF4444),
        title: JamStrings.loseTitle,
        body: baysFull ? JamStrings.loseBaysFull : JamStrings.loseStuck,
        actions: [
          _ChunkyButton(
            key: const ValueKey('jam-lose-undo'),
            label: JamStrings.undo,
            color: const Color(0xFF2F86F0),
            onTap: onUndo,
          ),
          _ChunkyButton(
            key: const ValueKey('jam-lose-retry'),
            label: JamStrings.retry,
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
    required this.onSkip,
  });

  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: _Card(
        key: const ValueKey('jam-pause-overlay'),
        icon: Icons.pause_circle_filled_rounded,
        iconColor: JamPalette.hud,
        title: JamStrings.paused,
        actions: [
          _ChunkyButton(
            key: const ValueKey('jam-resume'),
            label: JamStrings.resume,
            color: const Color(0xFF2EC05E),
            onTap: onResume,
          ),
          _ChunkyButton(
            key: const ValueKey('jam-pause-retry'),
            label: JamStrings.retry,
            color: const Color(0xFFFF8A1F),
            onTap: onRetry,
          ),
          _ChunkyButton(
            key: const ValueKey('jam-skip'),
            label: JamStrings.skipLevel,
            color: const Color(0xFF8D96A8),
            onTap: onSkip,
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

class _ChunkyButton extends StatelessWidget {
  const _ChunkyButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: JamPalette.hud, width: 2.5),
            boxShadow: const [
              BoxShadow(color: JamPalette.hud, offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2))],
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

  @override
  Widget build(BuildContext context) {
    final width = math.min(240.0, bounds.width - 24);
    final left = (anchor.dx - width / 2).clamp(12.0, bounds.width - width - 12);
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
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: JamPalette.hud,
          fontWeight: FontWeight.w800,
          fontSize: 15,
          height: 1.2,
        ),
      ),
    );
    return Positioned(
      left: left,
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
