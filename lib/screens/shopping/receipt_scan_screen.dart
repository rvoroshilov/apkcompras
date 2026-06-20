import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/shopping_list_item.dart';
import '../../models/supermarket.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../providers/supermarket_provider.dart';
import '../../utils/constants.dart';
import '../../utils/receipt_ocr.dart';
import '../../widgets/gradient_app_bar.dart';

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final List<_LineCtrl> _lines = [];
  bool _processing = false;
  bool _saving = false;
  bool _scanned = false;

  String _supermarketName = '';
  DateTime _date = DateTime.now();

  bool _addToStock = true;
  bool _savePrices = true;
  bool _recordSpend = true;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _total {
    double t = 0;
    for (final l in _lines) {
      if (l.include) t += _parse(l.price.text) * _parse(l.qty.text, def: 1);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final markets = context.watch<SupermarketProvider>().items;
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return Scaffold(
      appBar: GradientAppBar(
        title: const Text('Escanear ticket'),
        actions: [
          if (_scanned)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Escanear otro',
              onPressed: _processing ? null : _pickImage,
            ),
        ],
      ),
      body: _processing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Leyendo el ticket...'),
                ],
              ),
            )
          : !_scanned
              ? _IntroPicker(onPick: _pickImage)
              : _buildReview(markets, fmt),
      bottomNavigationBar: _scanned && !_processing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 12)),
                          Text(
                            fmt.format(_total),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: const Text('Guardar compra'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildReview(List<Supermarket> markets, NumberFormat fmt) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        // Tienda
        Text('Tienda', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...markets.map((m) => ChoiceChip(
                  label: Text(m.name),
                  selected: _supermarketName.toLowerCase() ==
                      m.name.toLowerCase(),
                  onSelected: (_) =>
                      setState(() => _supermarketName = m.name),
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(_supermarketName.isEmpty ||
                      markets.any((m) =>
                          m.name.toLowerCase() ==
                          _supermarketName.toLowerCase())
                  ? 'Otra'
                  : _supermarketName),
              onPressed: _newMarketDialog,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Fecha
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined),
          title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(_date)}'),
          onTap: _pickDate,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        const SizedBox(height: 16),

        // Opciones
        _OptionTile(
          value: _addToStock,
          title: 'Sumar al stock de la despensa',
          icon: Icons.kitchen_outlined,
          onChanged: (v) => setState(() => _addToStock = v),
        ),
        _OptionTile(
          value: _savePrices,
          title: 'Guardar precios por tienda',
          icon: Icons.sell_outlined,
          onChanged: (v) => setState(() => _savePrices = v),
        ),
        _OptionTile(
          value: _recordSpend,
          title: 'Registrar gasto del mes',
          icon: Icons.euro_outlined,
          onChanged: (v) => setState(() => _recordSpend = v),
        ),
        const Divider(height: 24),

        Row(
          children: [
            Text('Productos (${_lines.where((l) => l.include).length})',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _lines.add(_LineCtrl(name: ''))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No se detectaron productos.\nAñádelos a mano con el botón "Añadir".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          )
        else
          ..._lines.asMap().entries.map((e) => _LineRow(
                key: ValueKey(e.value),
                ctrl: e.value,
                onChanged: () => setState(() {}),
                onDelete: () => setState(() {
                  e.value.dispose();
                  _lines.removeAt(e.key);
                }),
              )),
      ],
    );
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Hacer foto del ticket'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 90, maxWidth: 1600);
    if (picked == null || !mounted) return;

    setState(() => _processing = true);
    try {
      final found = await ReceiptOcr.scan(picked.path);
      if (!mounted) return;
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      for (final r in found) {
        _lines.add(_LineCtrl(name: r.name, price: r.price));
      }
      setState(() {
        _scanned = true;
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _scanned = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo leer el ticket: $e')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _newMarketDialog() async {
    final ctrl = TextEditingController(
      text: _supermarketName,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la tienda'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Ej: Mercadona',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _supermarketName = name);
    }
  }

  Future<void> _save() async {
    final included = _lines
        .where((l) => l.include && l.name.text.trim().isNotEmpty)
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    if (included.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Añade al menos un producto')),
      );
      return;
    }
    final marketName = _supermarketName.trim();
    if (_savePrices && marketName.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Elige una tienda para guardar los precios')),
      );
      return;
    }

    // Warn about potential duplicate spend if the user already completed a list.
    bool doRecordSpend = _recordSpend;
    if (_recordSpend) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Registrar gasto?'),
          content: const Text(
            'Si ya has completado una lista de la compra para esta misma '
            'compra, el gasto se contaría dos veces en los gastos del mes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No registrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar igualmente'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == null) return;
      doRecordSpend = choice;
    }

    final supProv = context.read<SupermarketProvider>();
    final shopProv = context.read<ShoppingProvider>();
    final pantryProv = context.read<PantryProvider>();
    final prodProv = context.read<ProductProvider>();
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    try {
      String? marketId;
      if (marketName.isNotEmpty) {
        marketId = await supProv.ensureSupermarket(marketName);
      }

      if (doRecordSpend) {
        final items = included
            .map((l) => ShoppingListItem(
                  id: '',
                  listId: '',
                  productName: l.name.text.trim(),
                  unitPrice: _parse(l.price.text),
                  quantity: _parse(l.qty.text, def: 1),
                  unit: l.unit,
                ))
            .toList();
        final label = marketName.isEmpty
            ? 'Ticket ${DateFormat('dd/MM').format(_date)}'
            : 'Ticket $marketName ${DateFormat('dd/MM').format(_date)}';
        await shopProv.registerPurchase(
          name: label,
          date: _date,
          supermarketName: marketName,
          items: items,
        );
      }

      if (_addToStock) {
        for (final l in included) {
          await pantryProv.addStock(
            l.name.text.trim(),
            _parse(l.qty.text, def: 1),
            unit: l.unit,
          );
        }
      }

      if (_savePrices && marketId != null) {
        for (final l in included) {
          final price = _parse(l.price.text);
          if (price > 0) {
            await prodProv.recordPurchasePrice(
              supermarketId: marketId,
              name: l.name.text.trim(),
              price: price,
              unit: l.unit,
            );
          }
        }
      }

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Compra registrada correctamente')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  static double _parse(String s, {double def = 0}) =>
      double.tryParse(s.replaceAll(',', '.').trim()) ?? def;
}

// ── Editable line model + row ──────────────────────────────────────────────

class _LineCtrl {
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;
  String unit;
  bool include;

  _LineCtrl({
    required String name,
    double? price,
    double qty = 1,
    this.unit = 'ud',
    this.include = true,
  })  : name = TextEditingController(text: name),
        qty = TextEditingController(text: _fmtNum(qty)),
        price = TextEditingController(
            text: price != null ? price.toStringAsFixed(2) : '');

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }

  static String _fmtNum(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
}

class _LineRow extends StatelessWidget {
  final _LineCtrl ctrl;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _LineRow({
    super.key,
    required this.ctrl,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: ctrl.include,
                  onChanged: (v) {
                    ctrl.include = v ?? true;
                    onChanged();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: ctrl.name,
                    decoration: const InputDecoration(
                      hintText: 'Producto',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                  onPressed: onDelete,
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 48),
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: ctrl.qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cant.',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: DropdownButtonFormField<String>(
                    value: ctrl.unit,
                    isDense: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.units
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ctrl.unit = v;
                        onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ctrl.price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      isDense: true,
                      prefixText: '€ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final bool value;
  final String title;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const _OptionTile({
    required this.value,
    required this.title,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(icon),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _IntroPicker extends StatelessWidget {
  final VoidCallback onPick;
  const _IntroPicker({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Haz una foto del ticket de la compra y la app intentará leer '
              'los productos y precios automáticamente.\n\n'
              'Podrás revisarlos y corregirlos antes de guardar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Escanear ticket'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
