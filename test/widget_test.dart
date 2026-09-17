import 'package:flutter_test/flutter_test.dart';
import 'package:jamdigital/main.dart';

void main() {
  testWidgets('JamDigital renders the virtual P10 controller', (tester) async {
    await tester.pumpWidget(const Esp32ClockApp());

    expect(find.text('Virtual Device'), findsOneWidget);
    expect(
      find.text('Warna Jam Digital (Atas)', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('TES BEL JAM', skipOffstage: false), findsOneWidget);
  });
}
