import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import 'game_model.dart';
import 'game_session.dart';
import 'route_symbol.dart';

class DepotGame extends FlameGame {
  DepotGame(
    this.session, {
    this.onSuccessfulDispatch,
    this.reduceMotion = false,
  });

  final GameSession session;
  final ValueChanged<DispatchResult>? onSuccessfulDispatch;
  bool reduceMotion;

  @override
  Color backgroundColor() => const Color(0xFF152238);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(DepotBoard(session, reduceMotion: () => reduceMotion, game: this));
  }
}

class DepotBoard extends PositionComponent with TapCallbacks {
  DepotBoard(
    this.session, {
    required bool Function() reduceMotion,
    required DepotGame game,
  }) : _reduceMotion = reduceMotion,
       _game = game,
       super(anchor: Anchor.topLeft);

  final GameSession session;
  final bool Function() _reduceMotion;
  final DepotGame _game;
  static const double _dispatchDuration = 0.42;
  int _observedAnimationSerial = 0;
  double _dispatchProgress = 1;

  double get dispatchAnimationProgress => _dispatchProgress;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_reduceMotion()) {
      _dispatchProgress = 1;
      _observedAnimationSerial = session.animationSerial;
      return;
    }
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
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(size.x, size.y),
          const [Color(0xFF122034), Color(0xFF1B2B40)],
        ),
    );
    _drawYard(canvas, left, top, gridWidth, gridHeight, cellSize, level);
    _drawRoadNetwork(canvas, left, top, cellSize, level);
    _drawGate(canvas, left, top, cellSize, level);
    for (final bus in level.buses) {
      if (state.activeBusIds.contains(bus.id)) {
        final path = GameRules.routeToExit(level, state, bus.id);
        _drawBus(
          canvas,
          _center(left, top, cellSize, bus.position),
          cellSize,
          bus.route,
          angle: path != null && path.length > 1
              ? _directionAngle(path[0], path[1])
              : 0,
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
        final result = session.dispatch(bus.id);
        if (result?.changed == true) _game.onSuccessfulDispatch?.call(result!);
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
    canvas.drawRRect(
      yard.shift(const ui.Offset(0, 4)),
      ui.Paint()..color = const Color(0x6607111D),
    );
    canvas.drawRRect(
      yard,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(left, top),
          ui.Offset(left + width, top + height),
          const [Color(0xFF243950), Color(0xFF1C2C42)],
        ),
    );
    canvas.drawRRect(
      yard,
      ui.Paint()
        ..color = const Color(0xFF456078)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.35,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(left, top, width, height),
        const ui.Radius.circular(15),
      ),
      ui.Paint()
        ..color = const Color(0x183F607B)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1,
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
        final lot = ui.RRect.fromRectAndRadius(
          rect.deflate(cellSize * 0.045),
          ui.Radius.circular(cellSize * 0.17),
        );
        canvas.drawRRect(lot, ui.Paint()..color = const Color(0x3022354A));
        final block = ui.RRect.fromRectAndRadius(
          rect.deflate(cellSize * 0.105).shift(ui.Offset(0, cellSize * 0.025)),
          ui.Radius.circular(cellSize * 0.17),
        );
        canvas.drawRRect(
          block.shift(ui.Offset(0, cellSize * 0.035)),
          ui.Paint()..color = const Color(0x55303E50),
        );
        canvas.drawRRect(
          block,
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset(block.left, block.top),
              ui.Offset(block.right, block.bottom),
              const [Color(0xFF38516A), Color(0xFF2B4056)],
            ),
        );
        canvas.drawRRect(
          block,
          ui.Paint()
            ..color = const Color(0xFF60758A).withValues(alpha: 0.7)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = math.max(0.8, cellSize * 0.012),
        );
        final roof = ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(
            block.left + cellSize * 0.09,
            block.top + cellSize * 0.075,
            block.width - cellSize * 0.18,
            cellSize * 0.12,
          ),
          ui.Radius.circular(cellSize * 0.06),
        );
        canvas.drawRRect(roof, ui.Paint()..color = const Color(0xFF4A637B));
        final windowPaint = ui.Paint()..color = const Color(0xFF91B6C3);
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(
                block.left + cellSize * (0.15 + i * 0.22),
                block.top + cellSize * 0.31,
                cellSize * 0.14,
                cellSize * 0.13,
              ),
              ui.Radius.circular(cellSize * 0.045),
            ),
            windowPaint,
          );
        }
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(
              block.left + block.width * 0.42,
              block.top + cellSize * 0.62,
              block.width * 0.16,
              cellSize * 0.16,
            ),
            ui.Radius.circular(cellSize * 0.035),
          ),
          ui.Paint()..color = const Color(0xFF263A50),
        );
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
      ..color = const Color(0xFF526B80)
      ..strokeWidth = cellSize * 0.5
      ..strokeCap = ui.StrokeCap.round;
    final markingPaint = ui.Paint()
      ..color = const Color(0xFFD8C99B).withValues(alpha: 0.78)
      ..strokeWidth = math.max(1.4, cellSize * 0.027)
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
        final alongRoad = neighbor.x != point.x;
        canvas.drawLine(
          alongRoad
              ? middle - ui.Offset(cellSize * 0.085, 0)
              : middle - ui.Offset(0, cellSize * 0.085),
          alongRoad
              ? middle + ui.Offset(cellSize * 0.085, 0)
              : middle + ui.Offset(0, cellSize * 0.085),
          markingPaint,
        );
      }
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
    for (var stripe = -1; stripe <= 1; stripe++) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
            center: center + ui.Offset(0, stripe * cellSize * 0.105),
            width: cellSize * 0.37,
            height: math.max(1.2, cellSize * 0.025),
          ),
          ui.Radius.circular(cellSize * 0.02),
        ),
        ui.Paint()..color = const Color(0xFFAEC1CB).withValues(alpha: 0.64),
      );
    }
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
    double angle = 0,
    bool highlighted = false,
    double opacity = 1,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final body = ui.Rect.fromCenter(
      center: ui.Offset.zero,
      width: cellSize * 0.73,
      height: cellSize * 0.79,
    );
    final shadow = ui.RRect.fromRectAndRadius(
      body.shift(ui.Offset(0, cellSize * 0.055)),
      ui.Radius.circular(cellSize * 0.19),
    );
    canvas.drawRRect(
      shadow,
      ui.Paint()..color = const Color(0x660B1422).withValues(alpha: opacity),
    );
    final tirePaint = ui.Paint()
      ..color = const Color(0xFF152436).withValues(alpha: opacity);
    for (final side in [-1, 1]) {
      for (final row in [-1, 1]) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromCenter(
              center: ui.Offset(side * cellSize * 0.35, row * cellSize * 0.21),
              width: cellSize * 0.105,
              height: cellSize * 0.18,
            ),
            ui.Radius.circular(cellSize * 0.045),
          ),
          tirePaint,
        );
      }
    }
    final busBody = ui.RRect.fromRectAndRadius(
      body,
      ui.Radius.circular(cellSize * 0.19),
    );
    final baseColor = Color(route.colorValue);
    canvas.drawRRect(
      busBody,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(body.left, body.top),
          ui.Offset(body.right, body.bottom),
          [
            baseColor.withValues(alpha: opacity),
            Color.lerp(
              baseColor,
              const Color(0xFF193149),
              0.22,
            )!.withValues(alpha: opacity),
          ],
        ),
    );
    canvas.drawRRect(
      busBody,
      ui.Paint()
        ..color = const Color(0xFF162C40).withValues(alpha: 0.92 * opacity)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, cellSize * 0.025),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        body.deflate(cellSize * 0.045),
        ui.Radius.circular(cellSize * 0.15),
      ),
      ui.Paint()
        ..color = Colors.white.withValues(alpha: 0.22 * opacity)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, cellSize * 0.012),
    );

    final frontWindow = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(
        body.left + cellSize * 0.11,
        body.top + cellSize * 0.065,
        body.width - cellSize * 0.22,
        cellSize * 0.145,
      ),
      ui.Radius.circular(cellSize * 0.06),
    );
    canvas.drawRRect(
      frontWindow,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(frontWindow.left, frontWindow.top),
          ui.Offset(frontWindow.right, frontWindow.bottom),
          [
            const Color(0xFF16344B).withValues(alpha: opacity),
            const Color(0xFF294D63).withValues(alpha: opacity),
          ],
        ),
    );
    canvas.drawLine(
      ui.Offset(frontWindow.left + cellSize * 0.035, frontWindow.top + 2),
      ui.Offset(frontWindow.right - cellSize * 0.035, frontWindow.top + 2),
      ui.Paint()
        ..color = Colors.white.withValues(alpha: 0.36 * opacity)
        ..strokeWidth = math.max(0.8, cellSize * 0.012)
        ..strokeCap = ui.StrokeCap.round,
    );

    for (final side in [-1, 1]) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
            center: ui.Offset(side * cellSize * 0.245, cellSize * 0.015),
            width: cellSize * 0.065,
            height: cellSize * 0.14,
          ),
          ui.Radius.circular(cellSize * 0.025),
        ),
        ui.Paint()..color = const Color(0xFF24485C).withValues(alpha: opacity),
      );
      canvas.drawCircle(
        ui.Offset(side * cellSize * 0.245, body.top + cellSize * 0.035),
        cellSize * 0.025,
        ui.Paint()..color = const Color(0xFFFFF0B2).withValues(alpha: opacity),
      );
      canvas.drawCircle(
        ui.Offset(side * cellSize * 0.245, body.bottom - cellSize * 0.035),
        cellSize * 0.022,
        ui.Paint()..color = const Color(0xFFFF8875).withValues(alpha: opacity),
      );
    }
    drawRouteSymbol(
      canvas,
      ui.Offset(0, cellSize * 0.095),
      cellSize * 0.29,
      route,
      const Color(0xFF18263A).withValues(alpha: opacity),
    );
    if (highlighted) {
      canvas.drawRRect(
        busBody,
        ui.Paint()
          ..color = const Color(0xFFFFD166).withValues(alpha: 0.95 * opacity)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = math.max(2.2, cellSize * 0.055),
      );
    }
    canvas.restore();
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
      angle: _directionAngle(points[segment], points[segment + 1]),
      opacity: progress > 0.9 ? (1 - progress) / 0.1 : 1,
    );
  }

  double _directionAngle(GridPoint from, GridPoint to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    if (dx > 0) return math.pi / 2;
    if (dx < 0) return -math.pi / 2;
    if (dy > 0) return math.pi;
    return 0;
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
