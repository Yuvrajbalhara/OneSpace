import 'package:flutter_test/flutter_test.dart';
import 'package:onespace/main.dart';

void main() {
  testWidgets('OneSpace dashboard loads', (tester) async {
    await tester.pumpWidget(const OneSpaceApp());
    await tester.pumpAndSettle();
    expect(find.text('OneSpace'), findsOneWidget);
    expect(find.text('Good morning, Yuvraj'), findsOneWidget);
    expect(find.text('Recent items'), findsOneWidget);
  });
}
