import 'package:flutter_test/flutter_test.dart';
import 'package:hablotengo/app.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HablotengoApp());
    expect(find.text('Hablotengo'), findsOneWidget);
  });
}
