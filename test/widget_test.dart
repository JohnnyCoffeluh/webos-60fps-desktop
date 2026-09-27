import 'package:flutter_test/flutter_test.dart';
import 'package:webos2/main.dart';

void main() {
  testWidgets('WebOS boots smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WebOSApp());
    expect(find.text('WebOS Workspace'), findsOneWidget);
  });
}
