import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../widgets/aesthetic_nav_bar.dart';
import 'home/home_screen.dart';
import 'pantry/pantry_screen.dart';
import 'supermarkets/supermarkets_screen.dart';
import 'shopping/shopping_lists_screen.dart';
import 'shopping/receipt_scan_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final _screens = [
    const HomeScreen(),
    const PantryScreen(),
    const ReceiptScanScreen(asTab: true),
    const ShoppingListsScreen(),
    const SupermarketsScreen(),
  ];

  static const _navItems = [
    AestheticNavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Inicio'),
    AestheticNavItem(
        icon: Icons.kitchen_outlined,
        selectedIcon: Icons.kitchen,
        label: 'Despensa'),
    AestheticNavItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: 'Escanear'),
    AestheticNavItem(
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart,
        label: 'Compra'),
    AestheticNavItem(
        icon: Icons.store_outlined,
        selectedIcon: Icons.store,
        label: 'Tiendas'),
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
                      Expanded(
                        child: Text(
                          'Sin conexión — los cambios se sincronizarán al volver',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
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
          bottomNavigationBar: AestheticNavBar(
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => setState(() => _selectedIndex = i),
            items: _navItems,
          ),
        );
      },
    );
  }
}
