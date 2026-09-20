import 'package:flutter_test/flutter_test.dart';
import 'package:eurocar_margin/main.dart';
import 'package:eurocar_margin/theme/theme_controller.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App launches and shows bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: const EuroCarMarginApp(),
      ),
    );
    expect(find.text('Marché'), findsOneWidget);
    expect(find.text('Simulateur'), findsOneWidget);
    expect(find.text('Dossiers'), findsOneWidget);
  });
}
