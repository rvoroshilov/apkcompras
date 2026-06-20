import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pantry_item.dart';
import '../utils/backup_helper.dart';
import '../utils/constants.dart';

class PantryItemCard extends StatelessWidget {
  final PantryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PantryItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = item.isExpired
        ? AppConstants.danger
        : item.isExpiringSoon
            ? AppConstants.warning
            : item.isOutOfStock
                ? AppConstants.danger
                : AppConstants.success;
    final catColor = AppConstants.categoryColor(item.category); // primary tag color

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildImage(statusColor, catColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // All tags as small chips
                        ...item.tags.map((tag) {
                          final c = AppConstants.categoryColor(tag);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: c,
                              ),
                            ),
                          );
                        }),
                        Text(
                          '${_fmtQty(item.quantity)} ${item.unit}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        if (item.isOutOfStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppConstants.danger,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AGOTADO',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else if (item.isBelowMinStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppConstants.info,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'STOCK BAJO',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.notes,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[500], fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.expiryDate != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _expiryLabel(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM/yy').format(item.expiryDate!),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                  if (onDelete != null)
                    GestureDetector(
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: AppConstants.danger.withOpacity(0.7)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _expiryLabel() {
    if (item.isExpired) return 'Caducado';
    final days = item.daysUntilExpiry!;
    if (days == 0) return 'Hoy';
    if (days == 1) return 'Mañana';
    return 'En $days días';
  }

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

  Widget _buildImage(Color statusColor, Color catColor) {
    if (item.imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(BackupHelper.resolveImagePath(item.imagePath)),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(catColor),
        ),
      );
    }
    return _placeholder(catColor);
  }

  Widget _placeholder(Color catColor) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [catColor.withOpacity(0.15), catColor.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          AppConstants.categoryIcon(item.category),
          color: catColor.withOpacity(0.8),
          size: 28,
        ),
      );
}
