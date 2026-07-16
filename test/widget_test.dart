import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:leotena/main.dart';
import 'package:leotena/state/app_state.dart';

void main() {
  testWidgets('Leotena splash screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const LeotenaApp(),
      ),
    );

    expect(find.text('Leotena'), findsOneWidget);
  });
}
