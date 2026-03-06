import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';

void main() {
  testWidgets('AutoTradeX smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AutoTradeXApp());
    expect(find.text('AutoTradeX'), findsWidgets);
  });
}
