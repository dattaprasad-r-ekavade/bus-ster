import 'package:busster/game/parking_jam_model.dart';
import 'package:busster/game/parking_jam_screen.dart';
import 'package:busster/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo lot is dense and has a complete solution', () {
    final tutorial = createParkingJamTutorialLevel();
    final level = createParkingJamDemoLevel();

    expect(tutorial.vehicles, hasLength(8));
    expect(JamRules(tutorial).solve(), isNotNull);
    expect(level.vehicles, hasLength(12));
    expect(JamRules(level).solve(), isNotNull);
  });

  testWidgets('launch path presents the parking jam instead of road dispatch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BussterApp(levelList: const [], useParkingJamPrototype: true),
    );
    await tester.pump();

    expect(find.text('WAITING FOR A RIDE'), findsOneWidget);
    expect(find.text('2 LEFT'), findsOneWidget);
    expect(
      find.text('Tap the clear blue bus to board the first riders.'),
      findsOneWidget,
    );
    expect(find.text('PARKING LOT'), findsNothing);
    expect(find.text('BAYS'), findsOneWidget);
    expect(find.byKey(const ValueKey('coral-bus')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked tap names the obstruction and legal departure boards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: ParkingJamScreen(level: createParkingJamDemoLevel())),
    );
    await tester.pump();

    expect(
      find.text('Clear a lane, then bring the matching bus to the riders.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('coral-bus')));
    await tester.pump();
    expect(find.textContaining('coral-blocker'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gold-bus')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.byKey(const ValueKey('gold-bus')), findsNothing);
    expect(find.text('5 LEFT'), findsOneWidget);
    expect(find.textContaining('passenger boarded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact phone keeps the board and recovery controls visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ParkingJamScreen()));
    await tester.pump();

    expect(find.text('UNDO'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('HINT'), findsOneWidget);
    expect(find.byKey(const ValueKey('coral-bus')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial chain advances to the crowded second level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ParkingJamScreen()));
    await tester.pump();

    for (final id in const [
      'blue-bus',
      'lower-blocker',
      'coral-blocker',
      'coral-bus',
      'top-car',
      'upper-car',
      'middle-car',
      'lower-car',
    ]) {
      await tester.tap(find.byKey(ValueKey(id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
    }

    expect(find.text('NEXT LEVEL'), findsOneWidget);
    expect(
      find.text('Great work! Every rider and vehicle is clear.'),
      findsOneWidget,
    );
    await tester.tap(find.text('NEXT LEVEL'));
    await tester.pump();

    expect(find.text('LEVEL 02'), findsOneWidget);
    expect(find.text('6 LEFT'), findsOneWidget);
    expect(find.byKey(const ValueKey('gold-bus')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
