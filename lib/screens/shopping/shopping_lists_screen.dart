import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/shopping_list.dart';
import '../../providers/shopping_provider.dart';
import 'shopping_list_screen.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Listas de compra')),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.lists.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  children: [
                    if (provider.activeLists.isNotEmpty) ...[
                      _SectionHeader(
                          title: 'Activas',
                          count: provider.activeLists.length),
                      ...provider.activeLists.map((list) =>
                          _ShoppingListCard(
                            list: list,
                            onTap: () => _openList(list),
                            onDelete: () => _confirmDelete(list),
                          )),
                    ],
                    if (provider.completedLists.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SectionHeader(
                          title: 'Completadas',
                          count: provider.completedLists.length),
                      ...provider.completedLists.map((list) =>
                          _ShoppingListCard(
                            list: list,
                            onTap: () => _openList(list),
                            onDelete: () => _confirmDelete(list),
                          )),
                    ],
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text('¿Eliminar "${list.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<ShoppingProvider>().deleteList(list.id);
    }
  }
}

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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: list.isCompleted
                      ? Colors.green.withOpacity(0.15)
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  list.isCompleted
                      ? Icons.check_circle_outline
                      : Icons.shopping_cart_outlined,
                  color: list.isCompleted
                      ? Colors.green
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
                            color: theme.colorScheme.primary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[300]),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hay listas de compra.\nCrea una con el botón +.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
