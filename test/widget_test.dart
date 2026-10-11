import 'package:busster/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the first depot and rider queue', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BussterApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BUS-STER'), findsOneWidget);
    expect(find.textContaining('DEPOT 01'), findsOneWidget);
    expect(find.text('NEXT RIDERS'), findsOneWidget);
    expect(find.text('FIFO QUEUE'), findsOneWidget);
    expect(find.text('ROUTE TIP'), findsOneWidget);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('How to play'), findsOneWidget);
    expect(find.textContaining('Riders board from the front'), findsOneWidget);
  });
}
