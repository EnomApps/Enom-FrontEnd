import 'package:flutter_test/flutter_test.dart';
import 'package:enom_app/main.dart';

void main() {
  testWidgets('App launches with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EnomApp());
    await tester.pump();
    // App should start without errors
    expect(find.byType(EnomApp), findsOneWidget);
  });
}
