import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../providers/supermarket_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_app_bar.dart';
import 'repurchase_prediction_screen.dart';
import 'shopping_list_screen.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      appBar: GradientAppBar(
        title: const Text('Listas de compra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Toca reponer (predicción)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const RepurchasePredictionScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Lista sugerida (reponer despensa)',
            onPressed: _createSuggestedList,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: onPrimary,
          unselectedLabelColor: onPrimary.withOpacity(0.7),
          indicatorColor: onPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Mis listas'),
            Tab(icon: Icon(Icons.copy_outlined), text: 'Plantillas'),
          ],
        ),
      ),
      body: provider.loading
          ? const AppLoader()
          : TabBarView(
              controller: _tabController,
              children: [
                _ListsTab(provider: provider),
                _TemplatesTab(provider: provider),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva lista'),
      ),
    );
  }

  void _openList(ShoppingList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ShoppingListScreen(shoppingList: list)),
    );
  }

  /// Crea automáticamente una lista con todo lo que hay que reponer en la
  /// despensa (agotado o bajo de stock), rellenando el precio más barato
  /// conocido y la tienda donde está más barato.
  Future<void> _createSuggestedList() async {
    final pantry = context.read<PantryProvider>();
    final shop = context.read<ShoppingProvider>();
    final prodProv = context.read<ProductProvider>();
    final supProv = context.read<SupermarketProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final toRestock = pantry.needsRestock;
    if (toRestock.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'No hay nada que reponer: tu despensa está bien de stock 👍'),
      ));
      return;
    }

    // Precios conocidos para rellenar el más barato de cada producto.
    List<Product> products = const [];
    try {
      products = await prodProv.getAll();
    } catch (_) {}
    if (!mounted) return;

    final name = 'Reposición ${DateFormat('dd/MM').format(DateTime.now())}';
    final newList = await shop.addListReturning(name, 0);

    for (final p in toRestock) {
      final needed =
          (p.minStock > p.quantity) ? (p.minStock - p.quantity) : 1.0;
      final nm = p.name.trim().toLowerCase();
      Product? cheapest;
      for (final prod in products) {
        if (prod.name.trim().toLowerCase() != nm) continue;
        if (prod.price <= 0) continue;
        if (cheapest == null || prod.price < cheapest!.price) cheapest = prod;
      }
      await shop.addItem(ShoppingListItem(
        id: '',
        listId: newList.id,
        productName: p.name,
        quantity: needed,
        unit: p.unit,
        unitPrice: cheapest?.price ?? 0.0,
        supermarketName: cheapest != null
            ? (supProv.getById(cheapest!.supermarketId)?.name ?? '')
            : '',
      ));
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
          'Lista "$name" creada con ${toRestock.length} producto(s) por reponer'),
    ));
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ShoppingListScreen(shoppingList: newList)),
    );
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva lista de compra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la lista *',
                hintText: 'Ej: Compra semanal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Presupuesto (€)',
                hintText: 'Opcional',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final budget =
          double.tryParse(budgetCtrl.text.replaceAll(',', '.')) ?? 0.0;
      await context.read<ShoppingProvider>().addList(name, budget);
    }
  }

  Future<void> _confirmDelete(ShoppingList list) async {
    final ok = await confirmDialog(
      context,
      icon: Icons.delete_outline,
      title: list.isTemplate ? 'Eliminar plantilla' : 'Eliminar lista',
      message: '¿Eliminar "${list.name}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (ok && mounted) {
      context.read<ShoppingProvider>().deleteList(list.id);
    }
  }

  Future<void> _createFromTemplate(ShoppingList template) async {
    final nameCtrl =
        TextEditingController(text: '${template.name} (copia)');
    final budgetCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Usar plantilla: ${template.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la nueva lista',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Presupuesto (€, opcional)',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Crear lista'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final budget =
          double.tryParse(budgetCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final newList = await context
          .read<ShoppingProvider>()
          .createFromTemplate(template.id, name, budget);
      if (mounted) {
        _tabController.animateTo(0);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ShoppingListScreen(shoppingList: newList)),
        );
      }
    }
  }

  Future<void> _saveAsTemplate() async {
    final provider = context.read<ShoppingProvider>();
    final allLists = provider.activeLists + provider.completedLists;
    if (allLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Primero crea una lista de compra')),
      );
      return;
    }

    ShoppingList? selected;
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Guardar como plantilla'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ShoppingList>(
                decoration: const InputDecoration(
                  labelText: 'Basada en...',
                  border: OutlineInputBorder(),
                ),
                items: allLists
                    .map((l) =>
                        DropdownMenuItem(value: l, child: Text(l.name)))
                    .toList(),
                onChanged: (v) {
                  setDState(() {
                    selected = v;
                    if (v != null && nameCtrl.text.isEmpty) {
                      nameCtrl.text = v.name;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la plantilla',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted && selected != null) {
      final name =
          nameCtrl.text.trim().isEmpty ? selected!.name : nameCtrl.text.trim();
      final newList =
          await provider.createFromTemplate(selected!.id, name, 0);
      await provider.updateList(newList.copyWith(isTemplate: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plantilla "$name" guardada')),
        );
      }
    }
  }
}

// ── LIST TAB ──────────────────────────────────────────────────────────────────

class _ListsTab extends StatelessWidget {
  final ShoppingProvider provider;
  const _ListsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.activeLists.isEmpty && provider.completedLists.isEmpty) {
      return const _EmptyState();
    }
    final state =
        context.findAncestorStateOfType<_ShoppingListsScreenState>();
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        if (provider.activeLists.isNotEmpty) ...[
          _SectionHeader(
              title: 'Activas', count: provider.activeLists.length),
          ...provider.activeLists.map((list) => _ShoppingListCard(
                list: list,
                onTap: () => state?._openList(list),
                onDelete: () => state?._confirmDelete(list),
              )),
        ],
        if (provider.completedLists.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionHeader(
              title: 'Completadas',
              count: provider.completedLists.length),
          ...provider.completedLists.map((list) => _ShoppingListCard(
                list: list,
                onTap: () => state?._openList(list),
                onDelete: () => state?._confirmDelete(list),
              )),
        ],
      ],
    );
  }
}

// ── TEMPLATES TAB ─────────────────────────────────────────────────────────────

class _TemplatesTab extends StatelessWidget {
  final ShoppingProvider provider;
  const _TemplatesTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final templates = provider.templates;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Save-as-template button
        OutlinedButton.icon(
          onPressed: () =>
              (context.findAncestorStateOfType<_ShoppingListsScreenState>())
                  ?._saveAsTemplate(),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Guardar lista actual como plantilla'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44)),
        ),
        const SizedBox(height: 12),
        if (templates.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: AppEmptyState(
              icon: Icons.copy_outlined,
              title: 'Sin plantillas todavía',
              message:
                  'Guarda una lista como plantilla para reutilizarla fácilmente.',
            ),
          )
        else
          ...templates.map((t) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.copy_outlined,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                  title: Text(t.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Creada el ${DateFormat('dd/MM/yyyy', 'es_ES').format(t.createdAt)}'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: AppConstants.danger.withOpacity(0.7)),
                    onPressed: () =>
                        (context.findAncestorStateOfType<
                                _ShoppingListsScreenState>())
                            ?._confirmDelete(t),
                  ),
                  onTap: () =>
                      (context.findAncestorStateOfType<_ShoppingListsScreenState>())
                          ?._createFromTemplate(t),
                ),
              )),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingListCard extends StatelessWidget {
  final ShoppingList list;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ShoppingListCard({
    required this.list,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final dateFmt = DateFormat('dd MMM yyyy', 'es_ES');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: list.isCompleted
                      ? AppConstants.success.withOpacity(0.15)
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(
                  list.isCompleted
                      ? Icons.check_circle_outline
                      : Icons.shopping_cart_outlined,
                  color: list.isCompleted
                      ? AppConstants.success
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      list.isCompleted
                          ? 'Completada el ${dateFmt.format(list.completedAt!)}'
                          : 'Creada el ${dateFmt.format(list.createdAt)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[500]),
                    ),
                    if (list.hasBudget)
                      Text(
                        'Presupuesto: ${fmt.format(list.budget)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 12),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: AppConstants.danger.withOpacity(0.7)),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'No hay listas de compra',
      message: 'Crea tu primera lista para empezar a organizar la compra.',
      action: FilledButton.icon(
        onPressed: () =>
            context.findAncestorStateOfType<_ShoppingListsScreenState>()
                ?._showCreateDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva lista'),
      ),
    );
  }
}
