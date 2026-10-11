import 'dart:ui' show Color;

/// Colors used where route and bus shapes need to remain distinct from nearby
/// surfaces. Route identity is also carried by symbols and spoken labels.
abstract final class GamePalette {
  static const routeSymbolInk = Color(0xFF101A2A);
  static const busOutlineInk = Color(0xFF101A2A);
  static const roadSurface = Color(0xFF526B80);
  static const riderQueueSurface = Color(0xFF17243A);
  static const passengerMarkInk = Color(0xFF17283C);
}
