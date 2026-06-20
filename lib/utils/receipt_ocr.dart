import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Una línea candidata extraída de un ticket: un nombre de producto y,
/// opcionalmente, su precio detectado.
class ReceiptLine {
  String name;
  double? price;
  ReceiptLine({required this.name, this.price});
}

/// Lee un ticket de compra (imagen) con OCR on-device y devuelve las líneas
/// que parecen productos con precio. El usuario revisa/corrige el resultado
/// antes de guardar, así que esto solo es un punto de partida.
class ReceiptOcr {
  // Palabras que indican que una línea NO es un producto (totales, impuestos,
  // datos de la tienda, formas de pago, etc.).
  static final RegExp _skip = RegExp(
    r'(TOTAL|SUBTOTAL|IVA|I\.V\.A|BASE|IMPONIBLE|CUOTA|EFECTIVO|TARJETA|'
    r'CONTADO|CAMBIO|ENTREGADO|DEVOLUCI|DESCUENTO|\bDTO\b|ARTICULOS|ART[IÍ]CULOS|'
    r'N\.?I\.?F|C\.?I\.?F|TEL[E£]?FONO|\bTEL\b|FACTURA|TICKET|SIMPLIFICAD|'
    r'GRACIAS|VISITA|CAJA|FECHA|HORA|OPERAC|TPV|REDONDEO|UNIDADES|PRECIO)',
    caseSensitive: false,
  );

  // Un importe tipo 1,23 / 12.99 / 0,99 (coma o punto decimal, 2 decimales).
  static final RegExp _price = RegExp(r'\d{1,4}[.,]\d{2}');

  /// Procesa la imagen y devuelve las líneas candidatas a producto.
  static Future<List<ReceiptLine>> scan(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      final lines = <ReceiptLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final parsed = _parseLine(line.text);
          if (parsed != null) lines.add(parsed);
        }
      }
      return lines;
    } finally {
      await recognizer.close();
    }
  }

  static ReceiptLine? _parseLine(String raw) {
    final text = raw.trim();
    if (text.length < 3) return null;
    if (_skip.hasMatch(text)) return null;

    // Busca el último importe de la línea (suele ser el precio final).
    final matches = _price.allMatches(text).toList();
    if (matches.isEmpty) {
      // Línea sin precio: puede ser un nombre cuyo precio quedó en otra línea.
      // La incluimos sin precio para que el usuario lo complete si quiere.
      final name = _cleanName(text);
      if (name.length < 2 || !_hasLetters(name)) return null;
      return ReceiptLine(name: name);
    }

    final last = matches.last;
    final price = double.tryParse(last.group(0)!.replaceAll(',', '.'));
    var name = _cleanName(text.substring(0, last.start));
    // Si no quedó nombre antes del precio, descarta (línea solo numérica).
    if (name.length < 2 || !_hasLetters(name)) return null;
    return ReceiptLine(name: name, price: price);
  }

  static String _cleanName(String s) {
    // Quita cantidades sueltas al principio ("2 ", "1x", "0,500 kg") y espacios.
    var out = s.trim();
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    // Elimina símbolos de moneda o restos al final.
    out = out.replaceAll(RegExp(r'[€$]'), '').trim();
    return out;
  }

  static bool _hasLetters(String s) => RegExp(r'[a-zA-ZáéíóúñÁÉÍÓÚÑ]').hasMatch(s);
}
