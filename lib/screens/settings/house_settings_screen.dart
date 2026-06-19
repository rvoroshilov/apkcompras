import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../services/activity_service.dart';
import '../supermarkets/barcode_scanner_screen.dart';
import '../../providers/supermarket_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/gradient_app_bar.dart';

class HouseSettingsScreen extends StatefulWidget {
  const HouseSettingsScreen({super.key});

  @override
  State<HouseSettingsScreen> createState() => _HouseSettingsScreenState();
}

class _HouseSettingsScreenState extends State<HouseSettingsScreen> {
  final _codeController = TextEditingController();
  bool _joining = false;
  String? _error;
  List<Map<String, dynamic>> _members = [];
  bool _membersLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final members = await FirebaseService().getMembers();
    if (mounted) {
      setState(() {
        _members = members;
        _membersLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseService();
    final code = fs.houseCode ?? '------';
    final myName = fs.displayName;
    final houseName = fs.houseName;

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Casa compartida')),
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
                    'Pulsa para copiar · o escanea el QR',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 160,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Theme.of(context).colorScheme.primary,
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

          // House name
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Nombre de la casa',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          houseName != null && houseName.isNotEmpty
                              ? houseName
                              : 'Sin nombre — aparecerá en la pantalla de Inicio',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: houseName != null && houseName.isNotEmpty
                                    ? null
                                    : Colors.grey,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _editHouseName,
                        child: Text(
                            houseName != null && houseName.isNotEmpty
                                ? 'Cambiar'
                                : 'Añadir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // My display name
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Tu nombre',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          myName != null && myName.isNotEmpty
                              ? myName
                              : 'Sin nombre — el resto de tu casa no sabe quién eres',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: myName != null
                                    ? null
                                    : Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _editName,
                        child: Text(myName != null ? 'Cambiar' : 'Añadir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Members list
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Miembros de la casa',
                          style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: () {
                          setState(() => _membersLoading = true);
                          _loadMembers();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_membersLoading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_members.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aún nadie con nombre. Añade el tuyo arriba.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    )
                  else
                    ..._members.map((m) {
                      final isMe = m['id'] == FirebaseService().userId;
                      final name = (m['name'] as String?) ?? 'Miembro';
                      final lastSeenRaw = m['last_seen'];
                      String lastSeenStr = '';
                      if (lastSeenRaw != null) {
                        try {
                          final DateTime dt;
                          if (lastSeenRaw is Timestamp) {
                            dt = lastSeenRaw.toDate();
                          } else if (lastSeenRaw is String) {
                            dt = DateTime.parse(lastSeenRaw);
                          } else {
                            dt = DateTime.now();
                          }
                          lastSeenStr = _relativeTime(dt);
                        } catch (_) {}
                      }
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          isMe ? '$name (tú)' : name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: lastSeenStr.isNotEmpty
                            ? Text('Visto $lastSeenStr')
                            : null,
                      );
                    }),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
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
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton.filled(
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'Escanear QR',
                          onPressed: _scanQr,
                        ),
                      ),
                    ],
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

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'ahora mismo';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return DateFormat('d MMM', 'es_ES').format(dt);
  }

  Future<void> _scanQr() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned == null || !mounted) return;
    // Accept raw 6-char codes
    final code = scanned.trim().toUpperCase();
    if (code.length >= 6) {
      setState(() {
        _codeController.text = code.substring(0, 6);
        _error = null;
      });
    }
  }

  Future<void> _editName() async {
    final fs = FirebaseService();
    final ctrl = TextEditingController(text: fs.displayName ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: María',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && mounted) {
      await fs.setDisplayName(ctrl.text.trim());
      setState(() {});
      _loadMembers();
    }
  }

  Future<void> _editHouseName() async {
    final fs = FirebaseService();
    final ctrl = TextEditingController(text: fs.houseName ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la casa'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Casa de los García',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && mounted) {
      await fs.setHouseName(ctrl.text.trim());
      setState(() {});
    }
  }

  /// Re-subscribes all providers to the new household's Firestore streams.
  void _reloadProviders() {
    context.read<SupermarketProvider>().load();
    context.read<PantryProvider>().load();
    context.read<ShoppingProvider>().load();
    context.read<ProductProvider>().load();
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
        _reloadProviders();
        setState(() => _membersLoading = true);
        _loadMembers();
        ActivityService().log('joined_house',
            FirebaseService().displayName ?? 'Nuevo miembro');
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
        _reloadProviders();
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
