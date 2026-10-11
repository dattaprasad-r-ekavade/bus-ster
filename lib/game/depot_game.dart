import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import 'game_model.dart';
import 'game_session.dart';

class DepotGame extends FlameGame {
  DepotGame(this.session);

  final GameSession session;

  @override
  Color backgroundColor() => const Color(0xFF152238);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(DepotBoard(session));
  }
}

class DepotBoard extends PositionComponent with TapCallbacks {
  DepotBoard(this.session) : super(anchor: Anchor.topLeft);

  final GameSession session;
  static const double _dispatchDuration = 0.42;
  int _observedAnimationSerial = 0;
  double _dispatchProgress = 1;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (session.animationSerial != _observedAnimationSerial) {
      _observedAnimationSerial = session.animationSerial;
      _dispatchProgress = 0;
    } else if (_dispatchProgress < 1) {
      _dispatchProgress = math.min(
        1.0,
        _dispatchProgress + dt / _dispatchDuration,
      );
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final level = session.level;
    final state = session.state;
    final cellSize = math.min(
      (size.x - 28) / level.width,
      (size.y - 56) / level.height,
    );
    final gridWidth = cellSize * level.width;
    final gridHeight = cellSize * level.height;
    final left = (size.x - gridWidth) / 2;
    final top = (size.y - gridHeight) / 2 + 12;

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.x, size.y),
      ui.Paint()..color = const Color(0xFF152238),
    );
    _drawYard(canvas, left, top, gridWidth, gridHeight, cellSize, level);
    _drawRoadNetwork(canvas, left, top, cellSize, level);
    _drawGate(canvas, left, top, cellSize, level);
    for (final bus in level.buses) {
      if (state.activeBusIds.contains(bus.id)) {
        _drawBus(
          canvas,
          _center(left, top, cellSize, bus.position),
          cellSize,
          bus.route,
          highlighted: session.hintedBusId == bus.id,
        );
      }
    }
    final animation = session.lastDispatchAnimation;
    if (animation != null && _dispatchProgress < 1) {
      _drawDispatchAnimation(
        canvas,
        left,
        top,
        cellSize,
        animation,
        _dispatchProgress,
      );
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (session.isPaused) return;
    final level = session.level;
    final cellSize = math.min(
      (size.x - 28) / level.width,
      (size.y - 56) / level.height,
    );
    final left = (size.x - cellSize * level.width) / 2;
    final top = (size.y - cellSize * level.height) / 2 + 12;
    final x = ((event.localPosition.x - left) / cellSize).floor();
    final y = ((event.localPosition.y - top) / cellSize).floor();
    if (x < 0 || y < 0 || x >= level.width || y >= level.height) return;

    for (final bus in level.buses) {
      if (bus.position == GridPoint(x, y) &&
          session.state.activeBusIds.contains(bus.id)) {
        session.dispatch(bus.id);
        return;
      }
    }
  }

  void _drawYard(
    ui.Canvas canvas,
    double left,
    double top,
    double width,
    double height,
    double cellSize,
    LevelSpec level,
  ) {
    final yard = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(left - 7, top - 7, width + 14, height + 14),
      const ui.Radius.circular(22),
    );
    canvas.drawRRect(yard, ui.Paint()..color = const Color(0xFF1D2C43));
    canvas.drawRRect(
      yard,
      ui.Paint()
        ..color = const Color(0xFF334762)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        final rect = ui.Rect.fromLTWH(
          left + x * cellSize + 3,
          top + y * cellSize + 3,
          cellSize - 6,
          cellSize - 6,
        );
        if (level.roads.contains(GridPoint(x, y))) continue;
        final block = ui.RRect.fromRectAndRadius(
          rect.deflate(cellSize * 0.1),
          ui.Radius.circular(cellSize * 0.18),
        );
        canvas.drawRRect(block, ui.Paint()..color = const Color(0xFF25354D));
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(
              rect.left + cellSize * 0.15,
              rect.top + cellSize * 0.16,
              rect.width * 0.7,
              rect.height * 0.17,
            ),
            ui.Radius.circular(cellSize * 0.08),
          ),
          ui.Paint()..color = const Color(0xFF344762),
        );
        final windowPaint = ui.Paint()..color = const Color(0xFF46607C);
        for (var i = 0; i < 2; i++) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(
                rect.left + cellSize * (0.2 + i * 0.28),
                rect.top + cellSize * 0.42,
                cellSize * 0.18,
                cellSize * 0.18,
              ),
              ui.Radius.circular(cellSize * 0.04),
            ),
            windowPaint,
          );
        }
      }
    }
  }

  void _drawRoadNetwork(
    ui.Canvas canvas,
    double left,
    double top,
    double cellSize,
    LevelSpec level,
  ) {
    final roadPaint = ui.Paint()
      ..color = const Color(0xFF52647A)
      ..strokeWidth = cellSize * 0.48
      ..strokeCap = ui.StrokeCap.round;
    final lanePaint = ui.Paint()
      ..color = const Color(0xFF91A2B7).withValues(alpha: 0.42)
      ..strokeWidth = math.max(1.2, cellSize * 0.025)
      ..strokeCap = ui.StrokeCap.round;

    for (final point in level.roads) {
      for (final neighbor in [
        GridPoint(point.x + 1, point.y),
        GridPoint(point.x, point.y + 1),
      ]) {
        if (!level.roads.contains(neighbor)) continue;
        final a = _center(left, top, cellSize, point);
        final b = _center(left, top, cellSize, neighbor);
        canvas.drawLine(a, b, roadPaint);
        final middle = ui.Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final laneMark = neighbor.x == point.x
            ? ui.Rect.fromCenter(
                center: middle,
                width: lanePaint.strokeWidth,
                height: cellSize * 0.12,
              )
            : ui.Rect.fromCenter(
                center: middle,
                width: cellSize * 0.12,
                height: lanePaint.strokeWidth,
              );
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            laneMark,
            ui.Radius.circular(lanePaint.strokeWidth),
          ),
          lanePaint,
        );
      }
    }

    for (final point in level.roads) {
      final center = _center(left, top, cellSize, point);
      canvas.drawCircle(
        center,
        cellSize * 0.24,
        roadPaint..style = ui.PaintingStyle.fill,
      );
      canvas.drawCircle(center, cellSize * 0.035, lanePaint);
    }
  }

  void _drawGate(
    ui.Canvas canvas,
    double left,
    double top,
    double cellSize,
    LevelSpec level,
  ) {
    final center = _center(left, top, cellSize, level.exit);
    final gateRect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: ui.Offset(center.dx, top - cellSize * 0.23),
        width: cellSize * 0.76,
        height: cellSize * 0.38,
      ),
      ui.Radius.circular(cellSize * 0.12),
    );
    canvas.drawRRect(gateRect, ui.Paint()..color = const Color(0xFFFFC857));
    _drawText(
      canvas,
      'EXIT',
      ui.Offset(center.dx, top - cellSize * 0.23),
      math.max(8, cellSize * 0.16),
      const Color(0xFF26364E),
      bold: true,
    );
    canvas.drawCircle(
      center,
      cellSize * 0.35,
      ui.Paint()
        ..color = const Color(0xFFFFC857).withValues(alpha: 0.16)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawBus(
    ui.Canvas canvas,
    ui.Offset center,
    double cellSize,
    RouteKind route, {
    bool highlighted = false,
    double opacity = 1,
  }) {
    final body = ui.Rect.fromCenter(
      center: center,
      width: cellSize * 0.73,
      height: cellSize * 0.76,
    );
    final shadow = ui.RRect.fromRectAndRadius(
      body.shift(ui.Offset(0, cellSize * 0.055)),
      ui.Radius.circular(cellSize * 0.2),
    );
    canvas.drawRRect(
      shadow,
      ui.Paint()..color = const Color(0x660B1422).withValues(alpha: opacity),
    );
    final busBody = ui.RRect.fromRectAndRadius(
      body,
      ui.Radius.circular(cellSize * 0.2),
    );
    canvas.drawRRect(
      busBody,
      ui.Paint()..color = Color(route.colorValue).withValues(alpha: opacity),
    );
    canvas.drawRRect(
      busBody,
      ui.Paint()
        ..color = Colors.white.withValues(alpha: 0.7 * opacity)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = highlighted ? 3 : 1,
    );

    final frontWindow = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(
        body.left + cellSize * 0.11,
        body.top + cellSize * 0.08,
        body.width - cellSize * 0.22,
        cellSize * 0.2,
      ),
      ui.Radius.circular(cellSize * 0.08),
    );
    canvas.drawRRect(
      frontWindow,
      ui.Paint()..color = const Color(0xFF24374D).withValues(alpha: opacity),
    );
    _drawText(
      canvas,
      route.symbol,
      ui.Offset(center.dx, center.dy + cellSize * 0.12),
      cellSize * 0.31,
      const Color(0xFF18263A).withValues(alpha: opacity),
      bold: true,
    );
    canvas.drawCircle(
      ui.Offset(body.left + cellSize * 0.12, body.bottom - cellSize * 0.09),
      cellSize * 0.035,
      ui.Paint()..color = const Color(0xFF24374D).withValues(alpha: opacity),
    );
    canvas.drawCircle(
      ui.Offset(body.right - cellSize * 0.12, body.bottom - cellSize * 0.09),
      cellSize * 0.035,
      ui.Paint()..color = const Color(0xFF24374D).withValues(alpha: opacity),
    );
  }

  void _drawDispatchAnimation(
    ui.Canvas canvas,
    double left,
    double top,
    double cellSize,
    DispatchAnimation animation,
    double progress,
  ) {
    final points = animation.path;
    final routePaint = ui.Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.75)
      ..strokeWidth = math.max(3, cellSize * 0.09)
      ..strokeCap = ui.StrokeCap.round;
    for (var index = 0; index + 1 < points.length; index++) {
      canvas.drawLine(
        _center(left, top, cellSize, points[index]),
        _center(left, top, cellSize, points[index + 1]),
        routePaint,
      );
    }

    if (points.length == 1) {
      _drawBus(
        canvas,
        _center(left, top, cellSize, points.single),
        cellSize,
        animation.route,
        opacity: 1 - progress,
      );
      return;
    }

    final segmentCount = points.length - 1;
    final travel = progress * segmentCount;
    final segment = math.min(travel.floor(), segmentCount - 1);
    final segmentProgress = travel - segment;
    final from = _center(left, top, cellSize, points[segment]);
    final to = _center(left, top, cellSize, points[segment + 1]);
    final busCenter = ui.Offset(
      ui.lerpDouble(from.dx, to.dx, segmentProgress)!,
      ui.lerpDouble(from.dy, to.dy, segmentProgress)!,
    );
    _drawBus(
      canvas,
      busCenter,
      cellSize,
      animation.route,
      opacity: progress > 0.9 ? (1 - progress) / 0.1 : 1,
    );
  }

  ui.Offset _center(
    double left,
    double top,
    double cellSize,
    GridPoint point,
  ) => ui.Offset(
    left + (point.x + 0.5) * cellSize,
    top + (point.y + 0.5) * cellSize,
  );

  void _drawText(
    ui.Canvas canvas,
    String text,
    ui.Offset center,
    double size,
    ui.Color color, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? ui.FontWeight.w900 : ui.FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: ui.TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      center - ui.Offset(painter.width / 2, painter.height / 2),
    );
  }
}
