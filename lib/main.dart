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
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Material(
          color: context.appColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: context.appColors.cardBorder),
          ),
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: .28),
          child: Row(
            children: [
              Expanded(
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) {
                    setState(() {
                      _currentIndex = i;
                      if (i == 2) _historyRefresh++;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.travel_explore_outlined),
                      selectedIcon: Icon(Icons.travel_explore_rounded),
                      label: 'Marché',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.speed_outlined),
                      selectedIcon: Icon(Icons.speed_rounded),
                      label: 'Simulateur',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bookmark_outline_rounded),
                      selectedIcon: Icon(Icons.bookmark_rounded),
                      label: 'Dossiers',
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: context.appColors.cardBorder,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: IconButton(
                  onPressed: themeController.toggle,
                  tooltip: themeController.isDark
                      ? 'Passer au thème clair'
                      : 'Passer au thème sombre',
                  icon: Icon(
                    themeController.isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: context.appColors.accentOrange,
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
