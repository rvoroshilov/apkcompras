import 'package:flutter/material.dart';

/// Indicador de carga centrado que respeta el color primario del tema
/// activo (en lugar del azul Material por defecto).
class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
