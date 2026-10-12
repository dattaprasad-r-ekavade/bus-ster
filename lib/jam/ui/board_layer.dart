// Static scenery as a single bitmap.
//
// [JamBoardPainter] issues hundreds of draw calls (tiles, dashes, lot
// markings, tufts, trees). A RepaintBoundary only saves re-recording them:
// Impeller still replays the whole display list on every frame the scene
// animates. Rasterising the board once per layout turns it into one
// textured quad per frame.
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'board_painter.dart';
import 'jam_layout.dart';

class JamBoardLayer extends StatefulWidget {
  const JamBoardLayer({
    super.key,
    required this.layout,
    required this.bayCount,
  });

  final JamLayout layout;
  final int bayCount;

  @override
  State<JamBoardLayer> createState() => _JamBoardLayerState();
}

class _JamBoardLayerState extends State<JamBoardLayer> {
  ui.Image? _image;
  JamLayout? _forLayout;
  int _forBays = -1;
  double _forDpr = 0;

  ui.Image _imageFor(double dpr) {
    final cached = _image;
    if (cached != null &&
        identical(_forLayout, widget.layout) &&
        _forBays == widget.bayCount &&
        _forDpr == dpr) {
      return cached;
    }
    final size = widget.layout.size;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    JamBoardPainter(widget.layout, widget.bayCount).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * dpr).ceil().clamp(1, 1 << 14),
      (size.height * dpr).ceil().clamp(1, 1 << 14),
    );
    picture.dispose();
    cached?.dispose();
    _image = image;
    _forLayout = widget.layout;
    _forBays = widget.bayCount;
    _forDpr = dpr;
    return image;
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        size: widget.layout.size,
        painter: _ImagePainter(_imageFor(dpr), dpr),
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image, this.dpr);

  final ui.Image image;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, image.width / dpr, image.height / dpr),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter old) =>
      !identical(old.image, image) || old.dpr != dpr;
}
