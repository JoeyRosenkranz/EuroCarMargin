import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/search_screen.dart';
import 'screens/vehicle_form_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  final themeController = ThemeController();
  await themeController.load();
  runApp(
    ChangeNotifierProvider.value(
      value: themeController,
      child: const EuroCarMarginApp(),
    ),
  );
}

class EuroCarMarginApp extends StatelessWidget {
  const EuroCarMarginApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final isDark = controller.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            isDark ? AppColors.surface : AppLightColors.surface,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
    return MaterialApp(
      title: 'EuroCar Margin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: controller.mode,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _historyRefresh = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const SearchScreen(),
      const VehicleFormScreen(),
      HistoryScreen(key: ValueKey(_historyRefresh)),
    ];
    final themeController = context.watch<ThemeController>();
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.appColors.cardBorder, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) {
                    setState(() {
                      _currentIndex = i;
                      if (i == 2) _historyRefresh++;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.search_rounded),
                      label: 'Marché',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calculate_outlined),
                      selectedIcon: Icon(Icons.calculate_rounded),
                      label: 'Simulateur',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_rounded),
                      label: 'Dossiers',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton.filledTonal(
                  onPressed: themeController.toggle,
                  tooltip: themeController.isDark
                      ? 'Passer au thème clair'
                      : 'Passer au thème sombre',
                  icon: Icon(
                    themeController.isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
