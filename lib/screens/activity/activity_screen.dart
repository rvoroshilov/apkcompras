import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/activity_entry.dart';
import '../../services/activity_service.dart';
import '../../widgets/gradient_app_bar.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: Text('Actividad')),
      body: StreamBuilder<List<ActivityEntry>>(
        stream: ActivityService().stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return const _EmptyState();
          }
          // Group by date
          final grouped = <String, List<ActivityEntry>>{};
          for (final e in entries) {
            final key = _dayKey(e.timestamp);
            (grouped[key] ??= []).add(e);
          }
          final days = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: days.length,
            itemBuilder: (ctx, i) {
              final day = days[i];
              final dayEntries = grouped[day]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      _dayLabel(dayEntries.first.timestamp),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ...dayEntries.map((e) => _ActivityTile(entry: e)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Hoy';
    if (d == today.subtract(const Duration(days: 1))) return 'Ayer';
    return DateFormat('EEEE d MMMM', 'es_ES').format(dt);
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityEntry entry;
  const _ActivityTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconFor(entry.type);
    final timeFmt = DateFormat('HH:mm');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        entry.description,
        style: const TextStyle(fontSize: 14),
      ),
      trailing: Text(
        timeFmt.format(entry.timestamp),
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
    );
  }

  static (IconData, Color) _iconFor(String type) => switch (type) {
        'added_pantry' => (Icons.kitchen, Colors.green),
        'deleted_pantry' => (Icons.delete_outline, Colors.red),
        'completed_list' => (Icons.check_circle_outline, Colors.blue),
        'added_item' => (Icons.add_shopping_cart, Colors.purple),
        'joined_house' => (Icons.group_add, Colors.orange),
        _ => (Icons.info_outline, Colors.grey),
      };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aún no hay actividad.\nLas acciones de tu casa aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
