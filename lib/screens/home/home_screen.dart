import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/pantry_item.dart';
import '../../models/shopping_list.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../providers/supermarket_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/backup_helper.dart';
import '../../utils/constants.dart';
import '../settings/settings_screen.dart';
import '../spending/spending_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pantry = context.watch<PantryProvider>();
    final shopping = context.watch<ShoppingProvider>();
    final markets = context.watch<SupermarketProvider>();
    final settings = context.watch<SettingsProvider>();
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final monthFmt = DateFormat('MMMM yyyy', 'es_ES');

    final now = DateTime.now();
    final budget = shopping.monthlyBudget;
    final spend = shopping.monthlySpend;
    final budgetExceeded = budget > 0 && spend > budget;
    final budgetNearing = budget > 0 && !budgetExceeded && spend >= budget * 0.8;
    final belowMin = pantry.itemsBelowMinStock;
    final displayName = FirebaseService().displayName;
    final greeting = _greeting(now.hour, displayName);

    return Scaffold(
      backgroundColor: _scaffoldBg(cs, settings.backgroundStyle),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroHeader(
              greeting: greeting,
              title: FirebaseService().houseName?.isNotEmpty == true
                  ? FirebaseService().houseName!
                  : 'MiCompra',
              avatarEmoji: settings.avatarEmoji,
              backgroundStyle: settings.backgroundStyle,
              backgroundImage: settings.backgroundImage,
              onSettings: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // Budget card
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SpendingScreen())),
                  child: _BudgetCard(
                    spend: spend,
                    budget: budget,
                    budgetExceeded: budgetExceeded,
                    budgetNearing: budgetNearing,
                    fmt: fmt,
                    monthFmt: monthFmt,
                    now: now,
                  ),
                ),
                const SizedBox(height: 14),

                // Stats row — 4 gradient cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.shopping_cart_rounded,
                        label: 'Listas\nactivas',
                        value: shopping.activeLists.length.toString(),
                        gradientColors: const [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.store_rounded,
                        label: 'Super-\nmercados',
                        value: markets.items.length.toString(),
                        gradientColors: const [Color(0xFF11998e), Color(0xFF38ef7d)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.kitchen_rounded,
                        label: 'En\ndespensa',
                        value: pantry.items.length.toString(),
                        gradientColors: const [Color(0xFFf093fb), Color(0xFFf5576c)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: pantry.alertItems.isNotEmpty
                            ? Icons.warning_rounded
                            : Icons.check_circle_rounded,
                        label: 'Caducan\npronto',
                        value: pantry.alertItems.length.toString(),
                        gradientColors: pantry.alertItems.isNotEmpty
                            ? const [Color(0xFFf7971e), Color(0xFFffd200)]
                            : const [Color(0xFF56ab2f), Color(0xFFa8e063)],
                      ),
                    ),
                  ],
                ),

                // Expiry alerts
                if (pantry.alertItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    icon: Icons.warning_amber_rounded,
                    label: 'Alertas de caducidad',
                    color: AppConstants.warning,
                  ),
                  const SizedBox(height: 8),
                  ...pantry.alertItems.take(3).map(
                        (item) => _AlertRow(item: item, expired: item.isExpired),
                      ),
                  if (pantry.alertItems.length > 3)
                    _MoreHint(
                        'y ${pantry.alertItems.length - 3} más en la pestaña Despensa'),
                ],

                // Low stock
                if (belowMin.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    icon: Icons.inventory_2_rounded,
                    label: 'Stock bajo — ¿qué falta?',
                    color: AppConstants.info,
                  ),
                  const SizedBox(height: 8),
                  ...belowMin.take(5).map((item) => _StockRow(item: item)),
                  if (belowMin.length > 5)
                    _MoreHint('y ${belowMin.length - 5} más en Despensa'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _addLowStockToList(context, belowMin, shopping),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Añadir todo a la lista de compra'),
                    ),
                  ),
                ],

                // Active lists
                if (shopping.activeLists.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Listas activas',
                    color: cs.primary,
                  ),
                  const SizedBox(height: 8),
                  ...shopping.activeLists
                      .take(3)
                      .map((list) => _ListRow(list: list, fmt: fmt)),
                ],

                // Welcome empty state
                if (pantry.items.isEmpty &&
                    shopping.activeLists.isEmpty &&
                    belowMin.isEmpty) ...[
                  const SizedBox(height: 32),
                  const _EmptyHome(),
                ],

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Color _scaffoldBg(ColorScheme cs, int style) => switch (style) {
        1 => Color.lerp(cs.surface, cs.primaryContainer, 0.04)!,
        2 => Color.lerp(cs.surface, cs.primaryContainer, 0.09)!,
        _ => cs.surface,
      };

  static String _greeting(int hour, String? name) {
    final who = (name != null && name.isNotEmpty) ? ', $name' : '';
    if (hour < 12) return 'Buenos días$who ☀️';
    if (hour < 19) return 'Buenas tardes$who 🌤️';
    return 'Buenas noches$who 🌙';
  }

  Future<void> _addLowStockToList(
    BuildContext context,
    List<PantryItem> items,
    ShoppingProvider shopping,
  ) async {
    final activeLists = shopping.activeLists;
    if (activeLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No hay listas activas. Crea una lista de compra primero.')),
      );
      return;
    }

    ShoppingList targetList;
    if (activeLists.length == 1) {
      targetList = activeLists.first;
    } else {
      final picked = await showDialog<ShoppingList>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Añadir a lista'),
          children: activeLists
              .map((l) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, l),
                    child: Text(l.name),
                  ))
              .toList(),
        ),
      );
      if (picked == null || !context.mounted) return;
      targetList = picked;
    }

    await shopping.addFromPantryItems(targetList.id, items);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${items.length} producto${items.length == 1 ? '' : 's'} añadido${items.length == 1 ? '' : 's'} a "${targetList.name}"'),
          backgroundColor: AppConstants.success,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Hero header with gradient background
// ─────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String greeting;
  final String title;
  final String avatarEmoji;
  final int backgroundStyle;
  final String backgroundImage;
  final VoidCallback onSettings;

  const _HeroHeader({
    required this.greeting,
    required this.title,
    required this.avatarEmoji,
    required this.backgroundStyle,
    required this.backgroundImage,
    required this.onSettings,
  });

  List<Color> _gradientColors(ColorScheme cs) => switch (backgroundStyle) {
        0 => [cs.primary, cs.primary],
        2 => [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.65)!],
        _ => [cs.primary, Color.lerp(cs.primary, cs.primaryContainer, 0.55)!],
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = _gradientColors(cs);
    final hasImage = backgroundImage.isNotEmpty;
    final imageFile =
        hasImage ? File(BackupHelper.resolveImagePath(backgroundImage)) : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        image: imageFile != null
            ? DecorationImage(
                image: FileImage(imageFile),
                fit: BoxFit.cover,
                onError: (_, __) {},
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.30),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Stack(
        children: [
          // Degradado oscuro sobre la imagen para que el texto sea legible
          if (hasImage)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.10),
                      Colors.black.withOpacity(0.45),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Stack(
          children: [
            // Decorative background blobs
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.onPrimary.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: 20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.onPrimary.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 80,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.onPrimary.withOpacity(0.08),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            color: cs.onPrimary.withOpacity(0.85),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar emoji
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cs.onPrimary.withOpacity(0.35), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        avatarEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Settings button
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: cs.onPrimary.withOpacity(0.85),
                    ),
                    onPressed: onSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Gradient stat mini-cards
// ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradientColors;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Monthly budget card
// ─────────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final double spend;
  final double budget;
  final bool budgetExceeded;
  final bool budgetNearing;
  final NumberFormat fmt;
  final DateFormat monthFmt;
  final DateTime now;

  const _BudgetCard({
    required this.spend,
    required this.budget,
    required this.budgetExceeded,
    required this.budgetNearing,
    required this.fmt,
    required this.monthFmt,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = budgetExceeded
        ? AppConstants.danger
        : budgetNearing
            ? AppConstants.warning
            : cs.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withOpacity(0.13),
            baseColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: baseColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.euro_rounded, color: baseColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gasto de ${monthFmt.format(now)}',
                      style: TextStyle(
                        color: baseColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Toca para ver gráficos detallados',
                      style: TextStyle(
                          color: baseColor.withOpacity(0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.bar_chart_rounded,
                  color: baseColor.withOpacity(0.5), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            fmt.format(spend),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 34,
              color: baseColor,
              letterSpacing: -1.2,
            ),
          ),
          if (budget > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (spend / budget).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: baseColor.withOpacity(0.12),
                color: baseColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              budgetExceeded
                  ? '¡Presupuesto superado! (${fmt.format(budget)})'
                  : 'Presupuesto: ${fmt.format(budget)} · Resta: ${fmt.format(budget - spend)}',
              style: TextStyle(
                fontSize: 12,
                color: budgetExceeded
                    ? AppConstants.danger
                    : baseColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'en compras completadas',
                style: TextStyle(
                    color: baseColor.withOpacity(0.65), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section header with icon badge
// ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Alert / stock / list rows
// ─────────────────────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final PantryItem item;
  final bool expired;

  const _AlertRow({required this.item, required this.expired});

  @override
  Widget build(BuildContext context) {
    final color = expired ? AppConstants.danger : AppConstants.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.10), color.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.error_rounded : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: color.withOpacity(0.9)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              expired ? 'Caducado' : 'En ${item.daysUntilExpiry} días',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  final PantryItem item;

  const _StockRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.info.withOpacity(0.08),
            AppConstants.info.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppConstants.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              color: AppConstants.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child:
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            '${_fmtQty(item.quantity)}/${_fmtQty(item.minStock)} ${item.unit}',
            style: const TextStyle(
                fontSize: 12,
                color: AppConstants.info,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}

class _ListRow extends StatelessWidget {
  final ShoppingList list;
  final NumberFormat fmt;

  const _ListRow({required this.list, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.75), cs.primary],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_cart_rounded,
                color: Colors.white, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(list.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (list.hasBudget)
            Text(
              'Ppto: ${fmt.format(list.budget)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }
}

class _MoreHint extends StatelessWidget {
  final String text;
  const _MoreHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Center(
        child: Text(text,
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Welcome empty state
// ─────────────────────────────────────────────────────────────────

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.primaryContainer, cs.secondaryContainer],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.home_outlined, size: 52, color: cs.primary),
        ),
        const SizedBox(height: 22),
        Text(
          '¡Bienvenido a MiCompra!',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Empieza añadiendo productos a tu despensa\no creando una lista de la compra.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.grey[600], fontSize: 14, height: 1.55),
        ),
      ],
    );
  }
}
