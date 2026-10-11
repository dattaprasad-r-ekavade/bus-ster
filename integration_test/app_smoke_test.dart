import 'package:busster/game/parking_jam_screen.dart';
import 'package:busster/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches into the parking-jam screen', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ParkingJamScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
