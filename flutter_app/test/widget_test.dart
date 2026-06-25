import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ApiStudioApp());
    expect(find.text('API Studio'), findsOneWidget);
  });
}
