import 'package:flutter/material.dart';
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
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
        ],
      ),
    );
  }
}
