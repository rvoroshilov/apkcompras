import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shopping_list_item.dart';

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
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: item.isChecked,
                onChanged: (_) => onToggle?.call(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: item.isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.isChecked ? Colors.grey : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.hasDiscount)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${item.discountPercent.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        if (item.supermarketName.isNotEmpty) ...[
                          Icon(Icons.store, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Text(
                            item.supermarketName,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${_fmtQty(item.quantity)} ${item.unit}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        if (item.hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            fmt.format(item.unitPrice),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[400],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(item.totalPrice),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: item.isChecked
                          ? Colors.grey
                          : theme.colorScheme.primary,
                    ),
                  ),
                  if (onDelete != null)
                    GestureDetector(
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.delete_outline,
                            size: 16, color: Colors.red[300]),
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
