import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Una línea candidata extraída de un ticket: un nombre de producto y,
/// opcionalmente, su precio detectado.
class ReceiptLine {
  String name;
  double? price;
  ReceiptLine({required this.name, this.price});
}

/// Lee un ticket de compra (imagen) con OCR on-device y devuelve SOLO las
/// líneas que parecen productos comprados (nombre + precio). El usuario revisa
/// y corrige el resultado antes de guardar, así que esto es un punto de partida.
///
/// Regla principal: una línea solo se considera una compra si tiene un precio
/// (en la misma línea, o en la línea siguiente cuando el precio aparece suelto).
/// Así se descartan cabeceras, dirección, CIF, fechas, totales y pies de ticket
/// en lugar de "pillar todo el ticket".
class ReceiptOcr {
  // Palabras que indican que una línea NO es un producto (totales, impuestos,
  // datos de la tienda, formas de pago, fidelización, etc.).
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

  // Fechas (12/06/24) y horas (13:45) que pueden colarse con un número detrás.
  static final RegExp _dateOrTime =
      RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}|\d{1,2}:\d{2}');

  static final RegExp _letters = RegExp(r'[a-zA-ZáéíóúñÁÉÍÓÚÑ]');
  static final RegExp _word = RegExp(r'[a-zA-ZáéíóúñÁÉÍÓÚÑ]{2,}');

  /// Procesa la imagen y devuelve las líneas candidatas a producto.
  static Future<List<ReceiptLine>> scan(String imagePath) async {
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
      return _parse(raw);
    } finally {
      await recognizer.close();
    }
  }

  static List<ReceiptLine> _parse(List<String> raw) {
    final out = <ReceiptLine>[];
    for (var i = 0; i < raw.length; i++) {
      final text = raw[i];
      if (text.length < 3) continue;
      if (_skip.hasMatch(text)) continue;
      if (_dateOrTime.hasMatch(text)) continue;

      final matches = _price.allMatches(text).toList();

      if (matches.isEmpty) {
        // Línea sin precio. Solo la aceptamos si la SIGUIENTE línea es un
        // precio suelto (caso típico: nombre arriba, importe debajo).
        final next = (i + 1 < raw.length) ? _priceOnly(raw[i + 1]) : null;
        if (next == null) continue; // sin precio asociado → no es una compra
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

  /// Devuelve el precio si la línea es básicamente solo un importe
  /// ("1,23", "1,23 €", "12.99") sin texto. Si no, null.
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
    // Quita código de artículo al principio ("001234 ", "8412345 ").
    out = out.replaceFirst(RegExp(r'^\d{3,}\s+'), '');
    // Quita cantidad tipo "2 x" / "2x".
    out = out.replaceFirst(RegExp(r'^\d+\s*[xX]\s*'), '');
    // Quita cantidad/peso al principio ("2 ", "0,500 kg ", "1 L ").
    out = out.replaceFirst(
        RegExp(r'^\d+[.,]?\d*\s*(kg|g|l|ml|ud)?\s+', caseSensitive: false), '');
    return out.trim();
  }

  /// Un nombre válido tiene letras de verdad y no es ni un código ni una
  /// línea larguísima (direcciones, descripciones legales, etc.).
  static bool _isValidName(String s) {
    if (s.length < 2 || s.length > 40) return false;
    if (!_word.hasMatch(s)) return false; // al menos 2 letras seguidas
    return true;
  }
}
