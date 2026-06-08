import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final String supermarketName;
  final Color supermarketColor;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showSupermarket;

  const ProductCard({
    super.key,
    required this.product,
    this.supermarketName = '',
    this.supermarketColor = Colors.green,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.showSupermarket = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildImage(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSupermarket && supermarketName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: supermarketColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          supermarketName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: supermarketColor,
                          ),
                        ),
                      ),
                    Text(
                      product.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.brand.isNotEmpty)
                      Text(
                        product.brand,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    Text(
                      product.category,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(product.price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    '/ ${product.unit}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  if (product.hasNormalizedPrice)
                    Text(
                      '${fmt.format(product.pricePerKgOrL)}/${product.normalizedUnit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (onEdit != null || onDelete != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onEdit != null)
                          GestureDetector(
                            onTap: onEdit,
                            child: Icon(Icons.edit_outlined,
                                size: 18, color: Colors.grey[500]),
                          ),
                        if (onDelete != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onDelete,
                            child: Icon(Icons.delete_outline,
                                size: 18, color: Colors.red[300]),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (product.imagePath.isNotEmpty) {
      final file = File(product.imagePath);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: supermarketColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.shopping_bag_outlined,
          color: supermarketColor.withOpacity(0.6),
          size: 28,
        ),
      );
}
