// Colours, symbol shapes and scenery tones for the Bus Jam screen. Every
// shape is drawn as a path so it stays crisp and readable at any size.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../jam_model.dart';

/// Colour-blind helper shape paired with each [JamColor].
enum JamSymbol { heart, square, triangle, star, diamond, circle }

/// Shade set for one bus / rider colour.
class JamShade {
  const JamShade(this.base, this.dark, this.light, this.roof);

  final Color base;
  final Color dark;
  final Color light;
  final Color roof;
}

abstract final class JamPalette {
  // Saturated, distinct hues; luminance spread keeps them apart for most
  // colour-vision types, and every colour also carries its own symbol.
  static const Map<JamColor, JamShade> shades = {
    JamColor.red: JamShade(
      Color(0xFFEF4444),
      Color(0xFFA51D2A),
      Color(0xFFFF8F8F),
      Color(0xFFC92F3A),
    ),
    JamColor.blue: JamShade(
      Color(0xFF2F86F0),
      Color(0xFF16509E),
      Color(0xFF8CC3FF),
      Color(0xFF2267C2),
    ),
    JamColor.green: JamShade(
      Color(0xFF2EC05E),
      Color(0xFF167A39),
      Color(0xFF8BE8A9),
      Color(0xFF229A4A),
    ),
    JamColor.yellow: JamShade(
      Color(0xFFFFC928),
      Color(0xFFB58200),
      Color(0xFFFFE68A),
      Color(0xFFE6A800),
    ),
    JamColor.purple: JamShade(
      Color(0xFF9B5DE5),
      Color(0xFF5B2E9C),
      Color(0xFFCDB0F5),
      Color(0xFF7B44C4),
    ),
    JamColor.orange: JamShade(
      Color(0xFFFF8A1F),
      Color(0xFFB0520A),
      Color(0xFFFFC387),
      Color(0xFFE06E0C),
    ),
  };

  static JamShade of(JamColor color) => shades[color]!;

  static const Map<JamColor, JamSymbol> symbols = {
    JamColor.red: JamSymbol.heart,
    JamColor.blue: JamSymbol.square,
    JamColor.green: JamSymbol.triangle,
    JamColor.yellow: JamSymbol.star,
    JamColor.purple: JamSymbol.diamond,
    JamColor.orange: JamSymbol.circle,
  };

  static JamSymbol symbolOf(JamColor color) => symbols[color]!;

  // Scenery.
  static const grass = Color(0xFF7DCB5A);
  static const grassDark = Color(0xFF5FB043);
  static const grassLight = Color(0xFF97DA74);
  static const bush = Color(0xFF3F9A3C);
  static const bushLight = Color(0xFF63BE55);
  static const plaza = Color(0xFFFBE9C6);
  static const plazaTile = Color(0xFFF1D9AA);
  static const plazaEdge = Color(0xFFE2BE80);
  static const asphalt = Color(0xFF4A5368);
  static const asphaltLight = Color(0xFF545E75);
  static const road = Color(0xFF3D4558);
  static const kerb = Color(0xFFE9EDF3);
  static const kerbShadow = Color(0xFFB8C0CC);
  static const laneMark = Color(0xFFFFFFFF);
  static const roadDash = Color(0xFFFFD54A);
  static const stallFloor = Color(0xFF576178);
  static const windshield = Color(0xFFBFE6FF);
  static const windshieldDeep = Color(0xFF7EC3EE);
  static const headlight = Color(0xFFFFF4C2);
  static const taillight = Color(0xFFFF3B3B);
  static const skin = [
    Color(0xFFFFD9B5),
    Color(0xFFF2BE8C),
    Color(0xFFD99A66),
    Color(0xFFA9714A),
  ];
  static const hair = [
    Color(0xFF3B2A20),
    Color(0xFF7A4A24),
    Color(0xFF1F1F2B),
    Color(0xFFC88A3A),
  ];
  static const hud = Color(0xFF2B3550);
  static const hudText = Color(0xFFFFFFFF);
  static const accent = Color(0xFFFFC928);
}

/// Builds the outline of [symbol] centred on the origin, fitting a circle of
/// radius [r].
Path jamSymbolPath(JamSymbol symbol, double r) {
  switch (symbol) {
    case JamSymbol.circle:
      return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    case JamSymbol.square:
      final s = r * 0.86;
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: s * 2, height: s * 2),
          Radius.circular(r * 0.24),
        ),
      );
    case JamSymbol.triangle:
      return Path()
        ..moveTo(0, -r * 1.02)
        ..lineTo(r * 1.0, r * 0.78)
        ..lineTo(-r * 1.0, r * 0.78)
        ..close();
    case JamSymbol.diamond:
      return Path()
        ..moveTo(0, -r * 1.08)
        ..lineTo(r * 0.82, 0)
        ..lineTo(0, r * 1.08)
        ..lineTo(-r * 0.82, 0)
        ..close();
    case JamSymbol.star:
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final radius = i.isEven ? r * 1.08 : r * 0.47;
        final a = -math.pi / 2 + i * math.pi / 5;
        final p = Offset(math.cos(a) * radius, math.sin(a) * radius + r * 0.06);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    case JamSymbol.heart:
      return Path()
        ..moveTo(0, r * 0.92)
        ..cubicTo(-r * 1.35, -r * 0.02, -r * 0.82, -r * 1.12, 0, -r * 0.42)
        ..cubicTo(r * 0.82, -r * 1.12, r * 1.35, -r * 0.02, 0, r * 0.92)
        ..close();
  }
}

/// Paints [symbol] at [center], upright regardless of canvas rotation
/// applied by the caller (callers counter-rotate when needed).
void paintJamSymbol(
  Canvas canvas,
  JamSymbol symbol,
  Offset center,
  double r,
  Color color, {
  Color? outline,
}) {
  final path = jamSymbolPath(symbol, r).shift(center);
  canvas.drawPath(path, Paint()..color = color);
  if (outline != null) {
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.14)
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

/// Small easing helpers shared by the painters.
double smoothstep(double edge0, double edge1, double x) {
  if (edge1 == edge0) return x < edge0 ? 0 : 1;
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final u = t - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}
