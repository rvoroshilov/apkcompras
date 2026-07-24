/// Utilidades para cantidades que admiten fracciones (½, 1/2, 1 1/2, 0,5…).
///
/// [parseQuantity] es un superconjunto de `double.tryParse`: acepta lo mismo
/// que antes (coma o punto decimal) y además fracciones, por lo que puede
/// sustituir a los parseos existentes sin cambiar el comportamiento previo.

const Map<String, String> _unicodeFractions = {
  '½': '1/2',
  '⅓': '1/3',
  '⅔': '2/3',
  '¼': '1/4',
  '¾': '3/4',
  '⅕': '1/5',
  '⅛': '1/8',
};

/// Convierte texto a número admitiendo fracciones. Devuelve null si no se
/// puede interpretar (igual que `double.tryParse`).
double? parseQuantity(String input) {
  var s = input.trim().toLowerCase();
  if (s.isEmpty) return null;

  // Sustituye fracciones unicode por su forma "n/d" separada.
  _unicodeFractions.forEach((k, v) {
    s = s.replaceAll(k, ' $v ');
  });
  s = s.replaceAll(',', '.').trim();

  final parts = s.split(RegExp(r'\s+'));
  double total = 0;
  var any = false;
  for (final part in parts) {
    if (part.isEmpty) continue;
    if (part.contains('/')) {
      final f = part.split('/');
      if (f.length != 2) return null;
      final n = double.tryParse(f[0]);
      final d = double.tryParse(f[1]);
      if (n == null || d == null || d == 0) return null;
      total += n / d;
    } else {
      final v = double.tryParse(part);
      if (v == null) return null;
      total += v;
    }
    any = true;
  }
  return any ? total : null;
}

// Lista de pares (valor, símbolo). No se usa un Map<double,...> porque los
// double no admiten igualdad primitiva como clave de un mapa constante.
const List<(double, String)> _prettyFractions = [
  (0.5, '½'),
  (0.25, '¼'),
  (0.75, '¾'),
  (1 / 3, '⅓'),
  (2 / 3, '⅔'),
];

/// Muestra una cantidad de forma legible: 2 → "2", 0.5 → "½", 1.5 → "1½",
/// 0.7 → "0,7".
String formatQuantity(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  final whole = q.floor();
  final frac = q - whole;
  for (final (value, symbol) in _prettyFractions) {
    if ((frac - value).abs() < 0.02) {
      return whole == 0 ? symbol : '$whole$symbol';
    }
  }
  // Sin fracción "bonita": un decimal con coma (formato español).
  return q.toStringAsFixed(1).replaceAll('.', ',');
}
