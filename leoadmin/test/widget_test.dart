import 'package:flutter_test/flutter_test.dart';
import 'package:leoadmin/main.dart';

void main() {
  testWidgets('Login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const LeoAdminApp());
    await tester.pump();

    expect(find.text('LeoAdmin'), findsOneWidget);
    expect(find.text('Ingia'), findsOneWidget);
  });
}
