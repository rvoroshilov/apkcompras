import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/supermarket.dart';
import '../../providers/supermarket_provider.dart';
import '../../utils/constants.dart';
import 'supermarket_products_screen.dart';

class SupermarketsScreen extends StatefulWidget {
  const SupermarketsScreen({super.key});

  @override
  State<SupermarketsScreen> createState() => _SupermarketsScreenState();
}

class _SupermarketsScreenState extends State<SupermarketsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupermarketProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupermarketProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Supermercados')),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.items.isEmpty
              ? _EmptyState(onAdd: () => _showAddDialog(context))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: provider.items.length,
                  itemBuilder: (ctx, i) {
                    final s = provider.items[i];
                    return _SupermarketCard(
                      supermarket: s,
                      onTap: () => _openProducts(s),
                      onEdit: () => _showEditDialog(s),
                      onDelete: () => _confirmDelete(s),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Añadir tienda'),
      ),
    );
  }

  void _openProducts(Supermarket s) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SupermarketProductsScreen(supermarket: s)),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final provider = context.read<SupermarketProvider>();
    await _SupermarketDialog.show(
      context: context,
      onSave: (name, color) => provider.add(name, color),
      suggestedColor: provider.nextColor(),
    );
  }

  Future<void> _showEditDialog(Supermarket s) async {
    await _SupermarketDialog.show(
      context: context,
      existing: s,
      onSave: (name, color) =>
          context.read<SupermarketProvider>().update(s.copyWith(name: name, color: color)),
      suggestedColor: s.color,
    );
  }

  Future<void> _confirmDelete(Supermarket s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar supermercado'),
        content: Text(
            '¿Eliminar "${s.name}"?\nSe eliminarán todos sus productos.'),
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
      context.read<SupermarketProvider>().delete(s.id);
    }
  }
}

class _SupermarketCard extends StatelessWidget {
  final Supermarket supermarket;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupermarketCard({
    required this.supermarket,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = supermarket.flutterColor;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store, color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      supermarket.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ver productos →',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: Colors.white70, size: 20),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupermarketDialog extends StatefulWidget {
  final Supermarket? existing;
  final int suggestedColor;
  final void Function(String name, int color) onSave;

  const _SupermarketDialog({
    this.existing,
    required this.suggestedColor,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    Supermarket? existing,
    required int suggestedColor,
    required void Function(String name, int color) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _SupermarketDialog(
        existing: existing,
        suggestedColor: suggestedColor,
        onSave: onSave,
      ),
    );
  }

  @override
  State<_SupermarketDialog> createState() => _SupermarketDialogState();
}

class _SupermarketDialogState extends State<_SupermarketDialog> {
  late TextEditingController _nameCtrl;
  late int _color;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.suggestedColor;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nueva tienda' : 'Editar tienda'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre de la tienda',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Color:',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.supermarketColors.map((c) {
              final selected = _color == c.value;
              return GestureDetector(
                onTap: () => setState(() => _color = c.value),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(
                            color: Colors.white, width: 2)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: c.withOpacity(0.5),
                                blurRadius: 6)
                          ]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            widget.onSave(_nameCtrl.text.trim(), _color);
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hay supermercados.\nAñade uno con el botón +.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
