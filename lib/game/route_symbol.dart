import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'game_palette.dart';
import 'game_model.dart';

/// Draws route identity with vector geometry so it does not depend on a font.
void drawRouteSymbol(
  ui.Canvas canvas,
  ui.Offset center,
  double size,
  RouteKind route,
  ui.Color color,
) {
  final half = size * 0.42;
  final paint = ui.Paint()
    ..color = color
    ..style = ui.PaintingStyle.fill
    ..isAntiAlias = true;

  switch (route) {
    case RouteKind.coral:
      canvas.drawCircle(center, half * 0.9, paint);
    case RouteKind.blue:
      final path = ui.Path()
        ..moveTo(center.dx, center.dy - half)
        ..lineTo(center.dx + half, center.dy)
        ..lineTo(center.dx, center.dy + half)
        ..lineTo(center.dx - half, center.dy)
        ..close();
      canvas.drawPath(path, paint);
    case RouteKind.mint:
      final path = ui.Path()
        ..moveTo(center.dx, center.dy - half)
        ..lineTo(center.dx + half, center.dy + half * 0.78)
        ..lineTo(center.dx - half, center.dy + half * 0.78)
        ..close();
      canvas.drawPath(path, paint);
    case RouteKind.gold:
      final point = half * 0.45;
      final path = ui.Path()
        ..moveTo(center.dx, center.dy - half)
        ..lineTo(center.dx + point, center.dy - point)
        ..lineTo(center.dx + half, center.dy)
        ..lineTo(center.dx + point, center.dy + point)
        ..lineTo(center.dx, center.dy + half)
        ..lineTo(center.dx - point, center.dy + point)
        ..lineTo(center.dx - half, center.dy)
        ..lineTo(center.dx - point, center.dy - point)
        ..close();
      canvas.drawPath(path, paint);
  }
}

class RouteSymbol extends StatelessWidget {
  const RouteSymbol({
    super.key,
    required this.route,
    required this.color,
    this.size = 18,
  });

  final RouteKind route;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _RouteSymbolPainter(route, color),
  );
}

/// Draws the small project-authored bus mark used in a departure bay.
class MiniBusMark extends StatelessWidget {
  const MiniBusMark({super.key, required this.route, this.size = 22});

  final RouteKind route;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MiniBusPainter(route));
}

class _MiniBusPainter extends CustomPainter {
  const _MiniBusPainter(this.route);

  final RouteKind route;

  @override
  void paint(Canvas canvas, Size size) {
    final body = ui.Rect.fromLTWH(
      size.width * 0.17,
      size.height * 0.04,
      size.width * 0.66,
      size.height * 0.92,
    );
    final radius = ui.Radius.circular(size.shortestSide * 0.2);
    final rrect = ui.RRect.fromRectAndRadius(body, radius);
    canvas.drawRRect(
      rrect.shift(ui.Offset(0, size.height * 0.035)),
      ui.Paint()..color = const Color(0x6607111D),
    );
    canvas.drawRRect(rrect, ui.Paint()..color = Color(route.colorValue));
    canvas.drawRRect(
      rrect,
      ui.Paint()
        ..color = GamePalette.busOutlineInk
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.06,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(
          body.left + size.width * 0.12,
          body.top + size.height * 0.08,
          body.width - size.width * 0.24,
          size.height * 0.17,
        ),
        ui.Radius.circular(size.shortestSide * 0.08),
      ),
      ui.Paint()..color = const Color(0xFF19354B),
    );
    drawRouteSymbol(
      canvas,
      ui.Offset(size.width / 2, size.height * 0.65),
      size.shortestSide * 0.39,
      route,
      GamePalette.routeSymbolInk,
    );
  }

  @override
  bool shouldRepaint(_MiniBusPainter oldDelegate) => route != oldDelegate.route;
}

/// Draws a compact passenger silhouette beside the route symbol on a rider
/// token. Keeping it as vector geometry avoids another font glyph dependency.
class PassengerMark extends StatelessWidget {
  const PassengerMark({
    super.key,
    this.color = const Color(0xFF17283C),
    this.size = 11,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _PassengerPainter(color));
}

class _PassengerPainter extends CustomPainter {
  const _PassengerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()
      ..color = color
      ..isAntiAlias = true;
    canvas.drawCircle(
      ui.Offset(size.width * 0.5, size.height * 0.22),
      size.shortestSide * 0.15,
      paint,
    );
    final shoulders = ui.Path()
      ..moveTo(size.width * 0.12, size.height * 0.9)
      ..lineTo(size.width * 0.18, size.height * 0.63)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.42,
        size.width * 0.76,
        size.height * 0.42,
        size.width * 0.82,
        size.height * 0.63,
      )
      ..lineTo(size.width * 0.88, size.height * 0.9)
      ..close();
    canvas.drawPath(shoulders, paint);
  }

  @override
  bool shouldRepaint(_PassengerPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _RouteSymbolPainter extends CustomPainter {
  const _RouteSymbolPainter(this.route, this.color);

  final RouteKind route;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => drawRouteSymbol(
    canvas,
    ui.Offset(size.width / 2, size.height / 2),
    size.shortestSide,
    route,
    color,
  );

  @override
  bool shouldRepaint(_RouteSymbolPainter oldDelegate) =>
      route != oldDelegate.route || color != oldDelegate.color;
}
