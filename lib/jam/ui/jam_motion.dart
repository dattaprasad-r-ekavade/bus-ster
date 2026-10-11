// Motion primitives for the visual layer: bus poses, smooth rounded paths
// and arc-length legs with a trapezoidal (ease in, cruise, ease out) speed
// profile so buses travel at a near-constant speed.
import 'dart:math' as math;
import 'dart:ui';

/// Where and how big a bus is drawn. [angle] is the nose heading in radians
/// (0 = right, -pi/2 = up). [length] and [width] are in logical pixels.
class BusPose {
  const BusPose({
    required this.center,
    required this.angle,
    required this.length,
    required this.width,
  });

  final Offset center;
  final double angle;
  final double length;
  final double width;

  Offset get noseDirection => Offset(math.cos(angle), math.sin(angle));

  BusPose copyWith({Offset? center, double? angle}) => BusPose(
    center: center ?? this.center,
    angle: angle ?? this.angle,
    length: length,
    width: width,
  );
}

/// Builds a polyline through [points] whose corners are rounded with
/// quadratic curves of up to [radius] (clamped to half of each segment).
Path roundedPolyline(List<Offset> points, double radius) {
  final pts = <Offset>[];
  for (final p in points) {
    if (pts.isEmpty || (pts.last - p).distance > 0.5) pts.add(p);
  }
  // Drop interior points that are collinear with their neighbours.
  final clean = <Offset>[];
  for (var i = 0; i < pts.length; i++) {
    if (i > 0 && i < pts.length - 1) {
      final a = pts[i] - pts[i - 1];
      final b = pts[i + 1] - pts[i];
      final cross = a.dx * b.dy - a.dy * b.dx;
      if (cross.abs() < 1e-3 * a.distance * b.distance &&
          a.dx * b.dx + a.dy * b.dy > 0) {
        continue;
      }
    }
    clean.add(pts[i]);
  }
  final path = Path();
  if (clean.isEmpty) return path;
  path.moveTo(clean.first.dx, clean.first.dy);
  if (clean.length == 1) {
    path.lineTo(clean.first.dx + 0.01, clean.first.dy);
    return path;
  }
  for (var i = 1; i < clean.length - 1; i++) {
    final prev = clean[i - 1];
    final cur = clean[i];
    final next = clean[i + 1];
    final inLen = (cur - prev).distance;
    final outLen = (next - cur).distance;
    final r = math.min(radius, math.min(inLen, outLen) / 2);
    final inDir = (cur - prev) / inLen;
    final outDir = (next - cur) / outLen;
    final a = cur - inDir * r;
    final b = cur + outDir * r;
    path.lineTo(a.dx, a.dy);
    path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
  }
  path.lineTo(clean.last.dx, clean.last.dy);
  return path;
}

/// Maps normalised time to normalised distance for a trapezoidal velocity
/// profile: accelerate for [accel] of the time, cruise, decelerate for
/// [decel]. Continuous, monotonic, 0→0 and 1→1.
double trapezoidProgress(double t, {double accel = 0.18, double decel = 0.22}) {
  final u = t.clamp(0.0, 1.0);
  final vMax = 1 / (1 - accel / 2 - decel / 2);
  if (u < accel) {
    return 0.5 * vMax / accel * u * u;
  }
  final dA = 0.5 * vMax * accel;
  if (u <= 1 - decel) {
    return dA + vMax * (u - accel);
  }
  final r = 1 - u;
  return 1 - 0.5 * vMax / decel * r * r;
}

/// One continuous stretch of travel along [path].
class MotionLeg {
  MotionLeg({
    required Path path,
    required this.start,
    required this.duration,
    required this.fromSize,
    required this.toSize,
    this.reverse = false,
    this.accel = 0.18,
    this.decel = 0.22,
    this.sizeFrom = 0.1,
    this.sizeTo = 0.75,
  }) : _metric = _firstMetric(path) {
    length = _metric?.length ?? 0;
  }

  static PathMetric? _firstMetric(Path path) {
    final it = path.computeMetrics().iterator;
    return it.moveNext() ? it.current : null;
  }

  final PathMetric? _metric;
  late final double length;
  final double start;
  final double duration;

  /// Bus (length, width) at the start and end of the leg.
  final Size fromSize;
  final Size toSize;

  /// Driving backwards: the heading is opposite the path tangent.
  final bool reverse;
  final double accel;
  final double decel;

  /// Distance-fraction window over which the size morphs.
  final double sizeFrom;
  final double sizeTo;

  double get end => start + duration;

  BusPose poseAt(double time) {
    final t = duration <= 0 ? 1.0 : (time - start) / duration;
    final f = trapezoidProgress(t, accel: accel, decel: decel);
    final metric = _metric;
    Offset pos;
    double angle;
    if (metric == null || length <= 0) {
      pos = Offset.zero;
      angle = 0;
    } else {
      final tangent = metric.getTangentForOffset(
        (f * length).clamp(0.0, length),
      )!;
      pos = tangent.position;
      angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
      if (reverse) angle += math.pi;
    }
    final s = _smooth(sizeFrom, sizeTo, f);
    return BusPose(
      center: pos,
      angle: angle,
      length: lerpDouble(fromSize.width, toSize.width, s)!,
      width: lerpDouble(fromSize.height, toSize.height, s)!,
    );
  }

  static double _smooth(double a, double b, double x) {
    if (b <= a) return x < a ? 0 : 1;
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
