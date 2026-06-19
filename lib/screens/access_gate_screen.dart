import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/device_service.dart';

class AccessGateScreen extends StatelessWidget {
  final DeviceStatus status;
  const AccessGateScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deviceId = DeviceService().deviceId ?? '—';
    final isBlocked = status == DeviceStatus.blocked;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBlocked ? Icons.block_rounded : Icons.lock_clock_rounded,
                size: 80,
                color: isBlocked ? cs.error : cs.primary,
              ),
              const SizedBox(height: 24),
              Text(
                isBlocked ? 'Acceso bloqueado' : 'Esperando aprobación',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isBlocked ? cs.error : cs.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isBlocked
                    ? 'Este dispositivo ha sido bloqueado.\nContacta con el administrador.'
                    : 'Este dispositivo aún no ha sido aprobado.\nCuando el administrador lo apruebe en Firebase, la app se abrirá sola.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID de este dispositivo',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deviceId,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: cs.onSurface,
                                ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copiar ID',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: deviceId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('ID copiado al portapapeles')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isBlocked) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ve a Firebase Console → Firestore → devices → busca este ID → cambia status a "approved".',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
