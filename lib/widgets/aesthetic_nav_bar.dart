import 'package:flutter/material.dart';

/// Barra de navegación inferior flotante con indicador tipo "pill".
/// El elemento seleccionado se expande mostrando icono + etiqueta sobre
/// un fondo redondeado en el color del tema.
class AestheticNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<AestheticNavItem> items;

  const AestheticNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(items.length, (i) {
                final selected = i == selectedIndex;
                return _NavButton(
                  item: items[i],
                  selected: selected,
                  onTap: () => onItemSelected(i),
                  color: cs.primary,
                  onColor: cs.onPrimary,
                  idleColor: cs.onSurfaceVariant,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class AestheticNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AestheticNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _NavButton extends StatelessWidget {
  final AestheticNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Color onColor;
  final Color idleColor;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.color,
    required this.onColor,
    required this.idleColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              color: selected ? onColor : idleColor,
              size: 22,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: onColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
