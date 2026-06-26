import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Una línea candidata extraída de un ticket: nombre, precio UNITARIO y
/// cantidad detectada.
class ReceiptLine {
  String name;
  double? price; // precio por unidad
  double quantity;
  ReceiptLine({required this.name, this.price, this.quantity = 1});
}

/// Resultado completo de leer un ticket: las líneas de producto y, si se ha
/// podido reconocer, el nombre de la cadena de supermercado.
class ReceiptScanResult {
  final List<ReceiptLine> lines;
  final String? supermarket;
  ReceiptScanResult({required this.lines, this.supermarket});
}

/// Lee un ticket de compra (imagen) con OCR on-device y devuelve SOLO las
/// líneas que parecen productos comprados (nombre + precio), además de la
/// cadena de supermercado detectada. El usuario revisa/corrige el resultado
/// antes de guardar, así que esto es un punto de partida muy bueno, no perfecto.
///
/// Regla principal: una línea solo se considera una compra si tiene un precio
/// (en la misma línea, o como precio suelto en la siguiente). Así se descartan
/// cabeceras, dirección, CIF, fechas, totales y pies de ticket en lugar de
/// "pillar todo el ticket".
class ReceiptOcr {
  // Palabras que indican que una línea NO es un producto.
  static final RegExp _skip = RegExp(
    r'(TOTAL|SUBTOTAL|IVA|I\.V\.A|BASE|IMPONIBLE|CUOTA|IMPORTE|EFECTIVO|TARJETA|'
    r'CONTADO|CAMBIO|VUELTA|ENTREGADO|BIZUM|PAGAR|DEVOLUCI|DESCUENTO|\bDTO\b|'
    r'AHORRO|ARTICULOS|ART[IÍ]CULOS|N\.?I\.?F|C\.?I\.?F|TEL[E£]?FONO|\bTEL\b|'
    r'FACTURA|TICKET|SIMPLIFICAD|GRACIAS|VISITA|CAJA|FECHA|HORA|OPERAC|TPV|'
    r'REDONDEO|UNIDADES|\bPRECIO\b|PUNTOS|SOCIO|CLIENTE|EUROS?|\bPVP\b|P\.V\.P|'
    r'RESUMEN|FINANCIA|WWW|HTTP)',
    caseSensitive: false,
  );

  // Un importe tipo 1,23 / 12.99 / 0,99 (coma o punto decimal, 2 decimales).
  static final RegExp _price = RegExp(r'\d{1,4}[.,]\d{2}\b');

  // Cantidad por precio unitario: "2 x 1,50", "2x1,50", "3 UD x 0,99".
  static final RegExp _multi = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:ud|uds|u)?\s*[xX]\s*(\d{1,4}[.,]\d{2})\b',
    caseSensitive: false,
  );

  // Fechas (12/06/24) y horas (13:45).
  static final RegExp _dateOrTime =
      RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}|\d{1,2}:\d{2}');

  static final RegExp _letters = RegExp(r'[a-zA-ZáéíóúñÁÉÍÓÚÑ]');
  static final RegExp _word = RegExp(r'[a-zA-ZáéíóúñÁÉÍÓÚÑ]{2,}');

  // Cadenas de supermercado conocidas (España). Se busca por palabra completa
  // en el texto del ticket. El orden pone primero las más específicas.
  static final List<({String name, RegExp re})> _stores = [
    (name: 'Mercadona', re: RegExp(r'\bMERCADONA\b', caseSensitive: false)),
    (name: 'Carrefour', re: RegExp(r'\bCARREFOUR\b', caseSensitive: false)),
    (name: 'Hipercor', re: RegExp(r'\bHIPERCOR\b', caseSensitive: false)),
    (name: 'Supercor', re: RegExp(r'\bSUPERCOR\b', caseSensitive: false)),
    (name: 'El Corte Inglés', re: RegExp(r'CORTE\s+INGL', caseSensitive: false)),
    (name: 'Lidl', re: RegExp(r'\bLIDL\b', caseSensitive: false)),
    (name: 'Aldi', re: RegExp(r'\bALDI\b', caseSensitive: false)),
    (name: 'Dia', re: RegExp(r'\bDIA\b', caseSensitive: false)),
    (name: 'Eroski', re: RegExp(r'\bEROSKI\b', caseSensitive: false)),
    (name: 'Alcampo', re: RegExp(r'\bALCAMPO\b', caseSensitive: false)),
    (name: 'Consum', re: RegExp(r'\bCONSUM\b', caseSensitive: false)),
    (name: 'Ahorramas', re: RegExp(r'\bAHORRAM[AÁ]S\b', caseSensitive: false)),
    (name: 'Condis', re: RegExp(r'\bCONDIS\b', caseSensitive: false)),
    (name: 'Caprabo', re: RegExp(r'\bCAPRABO\b', caseSensitive: false)),
    (name: 'Bonpreu', re: RegExp(r'\bBONPREU\b', caseSensitive: false)),
    (name: 'Gadis', re: RegExp(r'\bGADIS\b', caseSensitive: false)),
    (name: 'Froiz', re: RegExp(r'\bFROIZ\b', caseSensitive: false)),
    (name: 'Coviran', re: RegExp(r'\bCOVIR[AÁ]N\b', caseSensitive: false)),
    (name: 'Spar', re: RegExp(r'\bSPAR\b', caseSensitive: false)),
    (name: 'Lupa', re: RegExp(r'\bLUPA\b', caseSensitive: false)),
  ];

  /// Procesa la imagen y devuelve los productos detectados y la tienda.
  static Future<ReceiptScanResult> scan(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      final raw = <String>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final t = line.text.trim();
          if (t.isNotEmpty) raw.add(t);
        }
      }
      return ReceiptScanResult(
        lines: _parse(raw),
        supermarket: _detectStore(raw),
      );
    } finally {
      await recognizer.close();
    }
  }

  static String? _detectStore(List<String> raw) {
    final text = raw.join(' ');
    for (final s in _stores) {
      if (s.re.hasMatch(text)) return s.name;
    }
    return null;
  }

  static List<ReceiptLine> _parse(List<String> raw) {
    final out = <ReceiptLine>[];
    for (var i = 0; i < raw.length; i++) {
      final text = raw[i];
      if (text.length < 3) continue;
      if (_skip.hasMatch(text)) continue;
      if (_dateOrTime.hasMatch(text)) continue;

      // Caso "N x precio_unitario": cantidad y precio por unidad explícitos.
      final mult = _multi.firstMatch(text);
      if (mult != null) {
        final qty = double.tryParse(mult.group(1)!.replaceAll(',', '.')) ?? 1;
        final unit = double.tryParse(mult.group(2)!.replaceAll(',', '.'));
        final name = _cleanName(text.substring(0, mult.start));
        if (_isValidName(name) && unit != null) {
          out.add(ReceiptLine(name: name, price: unit, quantity: qty));
          continue;
        }
      }

      final matches = _price.allMatches(text).toList();

      if (matches.isEmpty) {
        // Línea sin precio: solo vale si la SIGUIENTE línea es un precio suelto.
        final next = (i + 1 < raw.length) ? _priceOnly(raw[i + 1]) : null;
        if (next == null) continue;
        final name = _cleanName(text);
        if (!_isValidName(name)) continue;
        out.add(ReceiptLine(name: name, price: next));
        i++; // consume la línea del precio
        continue;
      }

      // Toma el último importe de la línea (suele ser el precio final).
      final last = matches.last;
      final price = double.tryParse(last.group(0)!.replaceAll(',', '.'));
      final name = _cleanName(text.substring(0, last.start));
      if (!_isValidName(name)) continue;
      out.add(ReceiptLine(name: name, price: price));
    }
    return out;
  }

  /// Devuelve el precio si la línea es básicamente solo un importe.
  static double? _priceOnly(String s) {
    final t = s.replaceAll(RegExp(r'[€$*\s]'), '');
    if (_letters.hasMatch(t)) return null;
    final m = _price.allMatches(s).toList();
    if (m.isEmpty) return null;
    return double.tryParse(m.last.group(0)!.replaceAll(',', '.'));
  }

  static String _cleanName(String s) {
    var out = s.trim();
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    out = out.replaceAll(RegExp(r'[€$*]'), '').trim();
    // Código de artículo al principio ("001234 ", "8412345 ").
    out = out.replaceFirst(RegExp(r'^\d{3,}\s+'), '');
    // Cantidad tipo "2 x" / "2x".
    out = out.replaceFirst(RegExp(r'^\d+\s*[xX]\s*'), '');
    // Cantidad/peso al principio ("2 ", "0,500 kg ", "1 L ").
    out = out.replaceFirst(
        RegExp(r'^\d+[.,]?\d*\s*(kg|g|l|ml|ud)?\s+', caseSensitive: false), '');
    return out.trim();
  }

  static bool _isValidName(String s) {
    if (s.length < 2 || s.length > 40) return false;
    if (!_word.hasMatch(s)) return false; // al menos 2 letras seguidas
    return true;
  }

  // ── Corrección difusa contra productos ya guardados ────────────────
  // Si el usuario ya ha comprado "Leche Entera Hacendado" antes, y el OCR
  // lee "LECHE ENTREA HACENDADO", lo reconocemos y usamos el nombre correcto.
  // Cuanto más compra el usuario, más "infalible" se vuelve el escáner.

  /// Devuelve el nombre conocido más parecido a [name] si la similitud supera
  /// el umbral; si no, null (se deja el texto del OCR tal cual).
  static String? bestMatch(String name, List<String> known,
      {double threshold = 0.82}) {
    final target = _norm(name);
    if (target.length < 4) return null;
    String? best;
    double bestScore = 0;
    for (final k in known) {
      final score = _similarity(target, _norm(k));
      if (score > bestScore) {
        bestScore = score;
        best = k;
      }
    }
    return bestScore >= threshold ? best : null;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áà]'), 'a')
      .replaceAll(RegExp(r'[éè]'), 'e')
      .replaceAll(RegExp(r'[íì]'), 'i')
      .replaceAll(RegExp(r'[óò]'), 'o')
      .replaceAll(RegExp(r'[úù]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1 - dist / maxLen;
  }

  static int _levenshtein(String a, String b) {
    final m = a.length, n = b.length;
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        var min = del < ins ? del : ins;
        if (sub < min) min = sub;
        curr[j] = min;
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }
}
