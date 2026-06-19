import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/supermarket_provider.dart';
import 'providers/product_provider.dart';
import 'providers/pantry_provider.dart';
import 'providers/shopping_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_screen.dart';
import 'screens/settings/settings_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => SupermarketProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProductProvider()..load()),
        ChangeNotifierProvider(create: (_) => PantryProvider()..load()),
        ChangeNotifierProvider(create: (_) => ShoppingProvider()..load()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final seed = Color(settings.seedColor);
          return MaterialApp(
            title: 'MiCompra',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: _buildTheme(seed, Brightness.light),
            darkTheme: _buildTheme(seed, Brightness.dark),
            home: const MainScreen(),
            routes: {'/settings': (_) => const SettingsScreen()},
          );
        },
      ),
    );
  }

  static ThemeData _buildTheme(Color seed, Brightness brightness) =>
      ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
        useMaterial3: true,
        cardTheme: const CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        chipTheme: const ChipThemeData(
          shape: StadiumBorder(),
        ),
      );
}
