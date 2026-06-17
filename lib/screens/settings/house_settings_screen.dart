import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/firebase_service.dart';

class HouseSettingsScreen extends StatefulWidget {
  const HouseSettingsScreen({super.key});

  @override
  State<HouseSettingsScreen> createState() => _HouseSettingsScreenState();
}

class _HouseSettingsScreenState extends State<HouseSettingsScreen> {
  final _codeController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseService();
    final code = fs.houseCode ?? '------';

    return Scaffold(
      appBar: AppBar(title: const Text('Casa compartida')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Current house code display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Tu código de casa',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado al portapapeles')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        code,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pulsa para copiar',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Share.share(
                        'Únete a mi lista de la compra en MiCompra. Usa el código: $code',
                        subject: 'Código de casa MiCompra',
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir código'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Explanation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Cómo funciona',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Comparte este código con tu familia para que todos vean y editen '
                    'la misma despensa y listas de la compra en tiempo real.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Join another house
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unirse a otra casa',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Código de 6 caracteres',
                      hintText: 'Ej: ABC123',
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _joining ? null : _joinHouse,
                      child: _joining
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unirse'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Leave house
          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: const Text('Abandonar esta casa'),
              subtitle: const Text('Se creará una nueva casa solo para ti'),
              textColor: Theme.of(context).colorScheme.error,
              onTap: _confirmLeave,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinHouse() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'El código debe tener 6 caracteres');
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final success = await FirebaseService().joinHouse(code);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te has unido a la casa correctamente')),
        );
        Navigator.pop(context);
      } else {
        setState(() => _error = 'No se encontró ninguna casa con ese código');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error al unirse: $e');
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonar casa'),
        content: const Text(
          'Si abandonas esta casa, dejarás de ver los datos compartidos. '
          'Se creará una nueva casa vacía solo para ti.\n\n'
          '¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await FirebaseService().leaveHouse();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Has abandonado la casa. Nueva casa creada.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
