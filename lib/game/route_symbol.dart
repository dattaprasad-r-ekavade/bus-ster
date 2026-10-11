import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

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
