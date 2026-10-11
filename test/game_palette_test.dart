import 'dart:math' as math;

import 'package:busster/game/game_model.dart';
import 'package:busster/game/game_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route marks contrast with their dark ink and queue surface', () {
    for (final route in RouteKind.values) {
      final routeColor = Color(route.colorValue);
      expect(
        _contrastRatio(routeColor, GamePalette.routeSymbolInk),
        greaterThanOrEqualTo(3),
        reason: '${route.name} symbol ink must be visible on its route fill',
      );
      expect(
        _contrastRatio(routeColor, GamePalette.riderQueueSurface),
        greaterThanOrEqualTo(3),
        reason: '${route.name} token must stand out from the rider queue',
      );
      expect(
        _contrastRatio(routeColor, GamePalette.busOutlineInk),
        greaterThanOrEqualTo(3),
        reason: '${route.name} bus body must contrast with its outline',
      );
    }
  });

  test('bus outline contrasts with the road surface', () {
    expect(
      _contrastRatio(GamePalette.busOutlineInk, GamePalette.roadSurface),
      greaterThanOrEqualTo(3),
    );
  });

  test('every route keeps a distinct symbol in grayscale', () {
    expect(
      RouteKind.values.map((route) => route.symbol).toSet(),
      hasLength(RouteKind.values.length),
    );
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = math.max(firstLuminance, secondLuminance);
  final darker = math.min(firstLuminance, secondLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}
