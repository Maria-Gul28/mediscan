import 'package:flutter_test/flutter_test.dart';
import 'package:mediscan/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MediScanApp());
    expect(find.byType(MediScanApp), findsOneWidget);
  });
}
