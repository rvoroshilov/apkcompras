import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'activity/activity_screen.dart';
import 'home/home_screen.dart';
import 'pantry/pantry_screen.dart';
import 'supermarkets/supermarkets_screen.dart';
import 'shopping/shopping_lists_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const _screens = [
    HomeScreen(),
    PantryScreen(),
    SupermarketsScreen(),
    ShoppingListsScreen(),
    ActivityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snap) {
        final results = snap.data ?? [];
        final offline = results.isNotEmpty &&
            results.every((r) => r == ConnectivityResult.none);

        return Scaffold(
          body: Column(
            children: [
              if (offline)
                MaterialBanner(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  content: const Row(
                    children: [
                      Icon(Icons.wifi_off, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Sin conexión — los cambios se sincronizarán al volver',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange[800],
                  actions: const [SizedBox.shrink()],
                ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.kitchen_outlined),
                selectedIcon: Icon(Icons.kitchen),
                label: 'Despensa',
              ),
              NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store),
                label: 'Tiendas',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart),
                label: 'Compra',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'Actividad',
              ),
            ],
          ),
        );
      },
    );
  }
}
