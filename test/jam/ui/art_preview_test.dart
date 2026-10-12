// Renders the procedural art to PNG sheets for visual review.
//
// Skipped unless ART_PREVIEW=1. Output goes to ART_PREVIEW_DIR (or the
// system temp folder) as art_<ART_PREVIEW_TAG>_<name>.png, e.g.
//   ART_PREVIEW=1 ART_PREVIEW_TAG=after flutter test test/jam/ui/art_preview_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_solver.dart';
import 'package:busster/jam/ui/bay_painter.dart';
import 'package:busster/jam/ui/board_painter.dart';
import 'package:busster/jam/ui/bus_painter.dart';
import 'package:busster/jam/ui/crowd_painter.dart';
import 'package:busster/jam/ui/jam_game_screen.dart';
import 'package:busster/jam/ui/jam_layout.dart';
import 'package:busster/jam/ui/jam_motion.dart';
import 'package:busster/jam/ui/jam_theme.dart';
import 'package:busster/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final bool _enabled = Platform.environment['ART_PREVIEW'] == '1';
final String _tag = Platform.environment['ART_PREVIEW_TAG'] ?? 'preview';
final String _dir =
    Platform.environment['ART_PREVIEW_DIR'] ?? Directory.systemTemp.path;

final List<JamLevel> _levels = JamLevelCodec.decodeBundle(
  File('assets/levels/jam_levels.json').readAsStringSync(),
);

class _FnPainter extends CustomPainter {
  _FnPainter(this.fn);
  final void Function(Canvas canvas, Size size) fn;
  @override
  void paint(Canvas canvas, Size size) => fn(canvas, size);
  @override
  bool shouldRepaint(_FnPainter old) => true;
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  Size size,
  double dpr,
  Widget child,
) async {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: key, child: child),
    ),
  );
  await tester.pump();
  await _save(tester, key, name, dpr);
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey key,
  String name,
  double dpr,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_dir${Platform.pathSeparator}art_${_tag}_$name.png');
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget _sheet(Size size, void Function(Canvas, Size) fn) => SizedBox(
  width: size.width,
  height: size.height,
  child: CustomPaint(size: size, painter: _FnPainter(fn)),
);

void _asphalt(Canvas canvas, Rect r) {
  canvas.drawRect(r, Paint()..color = JamPalette.asphalt);
}

void main() {
  const lotCell = 60.0;
  const parkedW = 35.0;

  testWidgets('buses', (tester) async {
    const colors = JamColor.values;
    const lengths = [2, 3, 4];
    final colW = lotCell * 4 + 20;
    final size = Size(colW * lengths.length + 20, 70.0 * colors.length + 20);
    await _capture(
      tester,
      'buses_lot',
      size,
      3,
      _sheet(size, (canvas, s) {
        _asphalt(canvas, Offset.zero & s);
        for (var ci = 0; ci < colors.length; ci++) {
          for (var li = 0; li < lengths.length; li++) {
            final len = lengths[li];
            final pose = BusPose(
              center: Offset(
                20 + li * colW + len * lotCell / 2,
                45.0 + ci * 70,
              ),
              angle: ci.isEven ? 0 : math.pi,
              length: len * lotCell - lotCell * 0.16,
              width: lotCell * JamLayout.lotWidthFactor,
            );
            paintBus(canvas, pose, colors[ci], const BusLook());
          }
        }
      }),
    );
  }, skip: !_enabled);

  testWidgets('buses parked', (tester) async {
    const colors = JamColor.values;
    const lengths = [2, 3, 4];
    const pitch = 48.0;
    final size = Size(pitch * colors.length * lengths.length + 20, 260);
    await _capture(
      tester,
      'buses_parked',
      size,
      3,
      _sheet(size, (canvas, s) {
        canvas.drawRect(
          Offset.zero & s,
          Paint()..color = JamPalette.stallFloor,
        );
        var k = 0;
        for (final len in lengths) {
          for (final c in colors) {
            final l = parkedW * JamLayout.parkedLengthFactor(len);
            final x = 30 + k * pitch;
            paintBus(
              canvas,
              BusPose(
                center: Offset(x, 10 + l / 2),
                angle: -math.pi / 2,
                length: l,
                width: parkedW,
              ),
              c,
              BusLook(seatsFilled: k % (len * 2 + 1), capacity: len * 2),
            );
            k++;
          }
        }
        // Small lot buses (compact phone) along the bottom.
        for (var i = 0; i < colors.length; i++) {
          paintBus(
            canvas,
            BusPose(
              center: Offset(40 + i * 70.0, 215),
              angle: i * math.pi / 3,
              length: 2 * 30 - 30 * 0.16,
              width: 30 * JamLayout.lotWidthFactor,
            ),
            colors[i],
            const BusLook(),
          );
        }
      }),
    );
  }, skip: !_enabled);

  testWidgets('bus close-up', (tester) async {
    const size = Size(400, 200);
    await _capture(
      tester,
      'bus_zoom',
      size,
      3,
      _sheet(size, (canvas, s) {
        _asphalt(canvas, Offset.zero & s);
        canvas.save();
        canvas.scale(1.8);
        paintBus(
          canvas,
          const BusPose(
            center: Offset(95, 28),
            angle: 0,
            length: 3 * lotCell - lotCell * 0.16,
            width: lotCell * JamLayout.lotWidthFactor,
          ),
          JamColor.red,
          const BusLook(),
        );
        paintBus(
          canvas,
          BusPose(
            center: const Offset(195, 55),
            angle: -math.pi / 2,
            length: parkedW * JamLayout.parkedLengthFactor(2),
            width: parkedW,
          ),
          JamColor.blue,
          const BusLook(seatsFilled: 3, capacity: 4),
        );
        paintBus(
          canvas,
          const BusPose(
            center: Offset(60, 85),
            angle: math.pi,
            length: 2 * 30 - 30 * 0.16,
            width: 30 * JamLayout.lotWidthFactor,
          ),
          JamColor.yellow,
          const BusLook(),
        );
        paintBus(
          canvas,
          const BusPose(
            center: Offset(120, 85),
            angle: math.pi / 2,
            length: 2 * 40 - 40 * 0.16,
            width: 40 * JamLayout.lotWidthFactor,
          ),
          JamColor.green,
          const BusLook(glow: 1),
        );
        canvas.restore();
      }),
    );
  }, skip: !_enabled);

  testWidgets('riders', (tester) async {
    const size = Size(420, 120);
    await _capture(
      tester,
      'riders',
      size,
      3,
      _sheet(size, (canvas, s) {
        canvas.drawRect(Offset.zero & s, Paint()..color = JamPalette.plaza);
        for (var i = 0; i < 12; i++) {
          final sp = i < 6 ? 40.0 : 28.0;
          paintRider(
            canvas,
            Offset(24.0 + i * 33, i < 6 ? 52 : 105),
            sp,
            JamColor.values[i % 6],
            i * 5,
          );
        }
      }),
    );
  }, skip: !_enabled);

  testWidgets('board', (tester) async {
    final level = _levels[11];
    const size = Size(412, 790);
    final layout = JamLayout.compute(size, level);
    await _capture(
      tester,
      'board',
      size,
      2.625,
      _sheet(size, (canvas, s) {
        JamBoardPainter(layout, level.bayCount).paint(canvas, s);
      }),
    );
    // Zoomed lot corners and a couple of stalls.
    const zoomSize = Size(360, 240);
    await _capture(
      tester,
      'zoom',
      zoomSize,
      3,
      _sheet(zoomSize, (canvas, s) {
        const z = 3.0;
        void view(Rect dst, Offset focus) {
          canvas.save();
          canvas.clipRect(dst);
          canvas.translate(dst.center.dx, dst.center.dy);
          canvas.scale(z);
          canvas.translate(-focus.dx, -focus.dy);
          JamBoardPainter(layout, level.bayCount).paint(canvas, size);
          canvas.restore();
        }

        final lot = layout.lotRect;
        view(const Rect.fromLTWH(0, 0, 120, 120), lot.topLeft);
        view(const Rect.fromLTWH(120, 0, 120, 120), lot.bottomRight);
        view(const Rect.fromLTWH(240, 0, 120, 120), lot.bottomLeft);
        final st = layout.stallRect(0);
        canvas.save();
        canvas.clipRect(const Rect.fromLTWH(0, 120, 360, 120));
        canvas.translate(10, 125);
        canvas.scale(2);
        canvas.translate(-st.left + 4, -st.top + 4);
        JamBoardPainter(layout, level.bayCount).paint(canvas, size);
        for (var i = 0; i < 2; i++) {
          paintStall(canvas, layout, i);
        }
        canvas.restore();
      }),
    );
  }, skip: !_enabled);

  testWidgets('game scene level 12', (tester) async {
    const size = Size(412, 915);
    const dpr = 2.625;
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: JamGameScreen(
            levels: _levels,
            initialLevelIndex: 11,
            solver: (r) async => solveJamRequest(r),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _save(tester, key, 'scene', dpr);
  }, skip: !_enabled);
}
