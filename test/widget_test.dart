import 'package:flutter_test/flutter_test.dart';
import 'package:eurocar_margin/main.dart';

void main() {
  testWidgets('App launches and shows bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(const EuroCarMarginApp());
    expect(find.text('Nouvelle'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
  });
}
