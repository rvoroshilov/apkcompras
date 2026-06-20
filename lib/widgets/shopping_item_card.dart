import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shopping_list_item.dart';
import '../utils/constants.dart';

class ShoppingItemCard extends StatelessWidget {
  final ShoppingListItem item;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ShoppingItemCard({
    super.key,
    required this.item,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final checked = item.isChecked;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: checked
            ? AppConstants.success.withOpacity(0.07)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: checked
              ? AppConstants.success.withOpacity(0.30)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Animated circular check button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: checked
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppConstants.success, Color(0xFF00897B)],
                          )
                        : null,
                    border: checked
                        ? null
                        : Border.all(
                            color: cs.outline.withOpacity(0.45),
                            width: 1.5,
                          ),
                    boxShadow: checked
                        ? [
                            BoxShadow(
                              color: AppConstants.success.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: checked
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: theme.textTheme.titleSmall!.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: checked
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor:
                                  AppConstants.success.withOpacity(0.6),
                              color: checked
                                  ? cs.onSurfaceVariant.withOpacity(0.6)
                                  : cs.onSurface,
                            ),
                            child: Text(
                              item.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (item.hasDiscount) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppConstants.danger.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusSm),
                            ),
                            child: Text(
                              '-${item.discountPercent.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.danger,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.supermarketName.isNotEmpty) ...[
                          Icon(Icons.store_outlined,
                              size: 11, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            item.supermarketName,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant, fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${_fmtQty(item.quantity)} ${item.unit}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant, fontSize: 11),
                        ),
                        if (item.hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            fmt.format(item.unitPrice),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withOpacity(0.5),
                              decoration: TextDecoration.lineThrough,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Price + delete
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.unitPrice > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: checked
                            ? AppConstants.success.withOpacity(0.12)
                            : cs.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        fmt.format(item.totalPrice),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: checked
                              ? AppConstants.success
                              : cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  if (onDelete != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Icon(Icons.delete_outline,
                            size: 16,
                            color: AppConstants.danger.withOpacity(0.55)),
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

  String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
