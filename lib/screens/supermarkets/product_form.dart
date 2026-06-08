import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/price_history.dart';
import '../../models/supermarket.dart';
import '../../providers/product_provider.dart';
import '../../utils/backup_helper.dart';
import '../../utils/constants.dart';
import 'barcode_scanner_screen.dart';

class ProductForm extends StatefulWidget {
  final Supermarket supermarket;
  final Product? existing;

  const ProductForm({
    super.key,
    required this.supermarket,
    this.existing,
  });

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _qtyPerUnitCtrl;
  String _category = 'General';
  String _unit = 'ud';
  String _imagePath = '';
  bool _saving = false;
  List<PriceHistory> _history = [];

  bool get _isEdit => widget.existing != null;
  bool get _hasNormalized => ['g', 'mL', 'kg', 'L'].contains(_unit);

  double get _normalizedPrice {
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final qty =
        double.tryParse(_qtyPerUnitCtrl.text.replaceAll(',', '.')) ?? 1;
    if (_unit == 'g') return qty > 0 ? (price / qty) * 1000 : price;
    if (_unit == 'mL') return qty > 0 ? (price / qty) * 1000 : price;
    return price;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _brandCtrl = TextEditingController(text: e?.brand ?? '');
    _barcodeCtrl = TextEditingController(text: e?.barcode ?? '');
    _priceCtrl = TextEditingController(
        text: e?.price.toStringAsFixed(2) ?? '');
    _qtyPerUnitCtrl = TextEditingController(
        text: e?.quantityPerUnit.toString() ?? '1');
    _category = e?.category ?? 'General';
    _unit = e?.unit ?? 'ud';
    _imagePath = e?.imagePath ?? '';

    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final history = await context
            .read<ProductProvider>()
            .getPriceHistory(widget.existing!.id);
        if (mounted) setState(() => _history = history);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _qtyPerUnitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar producto' : 'Nuevo producto'),
        backgroundColor: widget.supermarket.flutterColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Foto
            Center(child: _buildImagePicker()),
            const SizedBox(height: 20),

            // Escáner de código de barras
            OutlinedButton.icon(
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(_barcodeCtrl.text.isEmpty
                  ? 'Escanear código de barras'
                  : 'Cód: ${_barcodeCtrl.text}'),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto *',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Introduce un nombre' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(
                labelText: 'Marca (opcional)',
                prefixIcon: Icon(Icons.business_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: AppConstants.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),

            // Precio + unidad
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio (€) *',
                      prefixIcon: Icon(Icons.euro_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Número inválido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad *',
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.units
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cantidad por unidad (si aplica)
            if (['g', 'mL'].contains(_unit)) ...[
              TextFormField(
                controller: _qtyPerUnitCtrl,
                decoration: InputDecoration(
                  labelText:
                      'Cantidad por envase (${_unit}) *',
                  hintText: 'Ej: 500 para un paquete de 500g',
                  prefixIcon: const Icon(Icons.scale_outlined),
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (!['g', 'mL'].contains(_unit)) return null;
                  if (v == null || v.isEmpty) return 'Requerido';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 8),
            ],

            // Precio normalizado
            if (_hasNormalized && _priceCtrl.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Precio por ${_unit == 'g' || _unit == 'kg' ? 'kg' : 'L'}: '
                      '${fmt.format(_normalizedPrice)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Guardar cambios' : 'Añadir producto'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: widget.supermarket.flutterColor,
                  foregroundColor: Colors.white),
            ),

            // Historial de precios
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Historial de precios',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._history.take(10).map((h) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 18),
                    title: Text(fmt.format(h.price)),
                    trailing: Text(
                      DateFormat('dd/MM/yyyy').format(h.recordedAt),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                  )),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _imagePath.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(File(_imagePath), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 4),
                  Text('Foto del producto',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                ],
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final picked = await ImagePicker()
        .pickImage(source: choice, imageQuality: 70, maxWidth: 800);
    if (picked == null) return;
    final savedPath = await BackupHelper.saveImage(picked.path);
    if (mounted) setState(() => _imagePath = savedPath);
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() => _barcodeCtrl.text = result);
      // Try to find existing product with this barcode
      final existing =
          await context.read<ProductProvider>().getByBarcode(result);
      if (existing != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Producto encontrado: ${existing.name} - ya existe en el catálogo'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final price =
        double.parse(_priceCtrl.text.replaceAll(',', '.'));
    final qtyPerUnit = ['g', 'mL'].contains(_unit)
        ? double.parse(_qtyPerUnitCtrl.text.replaceAll(',', '.'))
        : 1.0;

    final provider = context.read<ProductProvider>();

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        name: _nameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        category: _category,
        imagePath: _imagePath,
        price: price,
        unit: _unit,
        quantityPerUnit: qtyPerUnit,
      );
      await provider.update(updated);
    } else {
      final product = Product(
        id: provider.generateId(),
        supermarketId: widget.supermarket.id,
        name: _nameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        category: _category,
        imagePath: _imagePath,
        price: price,
        unit: _unit,
        quantityPerUnit: qtyPerUnit,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await provider.add(product);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${widget.existing!.name}"?'),
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
      context
          .read<ProductProvider>()
          .delete(widget.supermarket.id, widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
