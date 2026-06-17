import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/pantry_item.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/backup_helper.dart';
import '../../utils/constants.dart';
import '../supermarkets/barcode_scanner_screen.dart';

class PantryItemForm extends StatefulWidget {
  final PantryItem? existing;
  const PantryItemForm({super.key, this.existing});

  @override
  State<PantryItemForm> createState() => _PantryItemFormState();
}

class _PantryItemFormState extends State<PantryItemForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _minStockCtrl;
  String _unit = 'ud';
  DateTime? _expiryDate;
  String _imagePath = '';
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _quantityCtrl =
        TextEditingController(text: e?.quantity.toString() ?? '1');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _minStockCtrl = TextEditingController(
        text: (e?.minStock ?? 0) > 0 ? e!.minStock.toString() : '');
    _unit = e?.unit ?? 'ud';
    _expiryDate = e?.expiryDate;
    _imagePath = e?.imagePath ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar producto' : 'Añadir a despensa'),
        actions: [
          if (!_isEdit)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              tooltip: 'Escanear código de barras',
              onPressed: _scanBarcode,
            ),
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
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
            Center(child: _ImagePicker()),
            const SizedBox(height: 20),

            // Nombre
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

            // Cantidad + unidad
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerida';
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
                      labelText: 'Unidad',
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Fecha de caducidad
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(_expiryDate == null
                  ? 'Fecha de caducidad (opcional)'
                  : 'Caduca: ${DateFormat('dd/MM/yyyy').format(_expiryDate!)}'),
              subtitle: _expiryDate != null
                  ? null
                  : const Text('Toca para establecer'),
              trailing: _expiryDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _expiryDate = null),
                    )
                  : null,
              onTap: _pickExpiryDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 12),

            // Stock mínimo
            TextFormField(
              controller: _minStockCtrl,
              decoration: InputDecoration(
                labelText: 'Stock mínimo (opcional)',
                hintText: 'Alerta cuando bajas de esta cantidad',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                suffixText: _unit,
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // Notas
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Guardar
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Guardar cambios' : 'Añadir a despensa'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ImagePicker() {
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
                child: Image.file(
                    File(BackupHelper.resolveImagePath(_imagePath)),
                    fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 4),
                  Text('Foto',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    final product = await context.read<ProductProvider>().getByBarcode(barcode);
    if (!mounted) return;

    if (product != null) {
      setState(() {
        _nameCtrl.text = product.name;
        _unit = product.unit;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Producto encontrado: ${product.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código no encontrado en el catálogo. Introduce el nombre manualmente.'),
        ),
      );
    }
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

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final qty =
        double.parse(_quantityCtrl.text.replaceAll(',', '.'));
    final minStock =
        double.tryParse(_minStockCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final provider = context.read<PantryProvider>();

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        name: _nameCtrl.text.trim(),
        quantity: qty,
        unit: _unit,
        expiryDate: _expiryDate,
        clearExpiryDate: _expiryDate == null,
        imagePath: _imagePath,
        notes: _notesCtrl.text.trim(),
        minStock: minStock,
      );
      await provider.update(updated);
    } else {
      await provider.add(PantryItem(
        id: '',
        name: _nameCtrl.text.trim(),
        quantity: qty,
        unit: _unit,
        expiryDate: _expiryDate,
        imagePath: _imagePath,
        notes: _notesCtrl.text.trim(),
        minStock: minStock,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
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
      await context.read<PantryProvider>().delete(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
