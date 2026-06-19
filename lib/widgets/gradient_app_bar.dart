import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// AppBar con fondo degradado coherente con la cabecera de Inicio.
/// Respeta el estilo de fondo elegido por el usuario (plano/suave/degradado).
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool centerTitle;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.leading,
    this.centerTitle = true,
  });

  static List<Color> gradientColors(ColorScheme cs, int style) =>
      switch (style) {
        0 => [cs.primary, cs.primary],
        2 => [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.65)!],
        _ => [cs.primary, Color.lerp(cs.primary, cs.primaryContainer, 0.55)!],
      };

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = context.watch<SettingsProvider>().backgroundStyle;
    final colors = gradientColors(cs, style);

    return AppBar(
      title: title,
      actions: actions,
      bottom: bottom,
      leading: leading,
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: cs.onPrimary,
      iconTheme: IconThemeData(color: cs.onPrimary),
      actionsIconTheme: IconThemeData(color: cs.onPrimary),
      titleTextStyle: TextStyle(
        color: cs.onPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      ),
    );
  }
}
