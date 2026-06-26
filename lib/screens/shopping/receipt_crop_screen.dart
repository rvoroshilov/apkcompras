import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/gradient_app_bar.dart';

/// Pantalla para recortar el ticket antes de leerlo. El usuario arrastra dos
/// guías horizontales (arriba y abajo) para quedarse solo con la zona de los
/// productos y dejar fuera cabecera y pie. Devuelve la ruta de la imagen
/// recortada (PNG temporal) o la original si se usa entera / hay algún fallo.
class ReceiptCropScreen extends StatefulWidget {
  final String imagePath;
  const ReceiptCropScreen({super.key, required this.imagePath});

  @override
  State<ReceiptCropScreen> createState() => _ReceiptCropScreenState();
}

class _ReceiptCropScreenState extends State<ReceiptCropScreen> {
  ui.Image? _image;
  double _top = 0.0; // fracción 0..1 de la altura
  double _bottom = 1.0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final img = await ui.decodeImageFromList(bytes);
      if (mounted) setState(() => _image = img);
    } catch (_) {
      // Si no se puede decodificar, seguimos con la imagen entera.
      if (mounted) Navigator.pop(context, widget.imagePath);
    }
  }

  Future<void> _confirm() async {
    final img = _image;
    if (img == null) return;
    setState(() => _busy = true);
    try {
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      final top = _top.clamp(0.0, 1.0) * h;
      final bottom = _bottom.clamp(0.0, 1.0) * h;
      final cropH = bottom - top;
      // Si apenas se recorta o es demasiado fino, usa la imagen entera.
      if (cropH < 20 || (_top <= 0.01 && _bottom >= 0.99)) {
        if (mounted) Navigator.pop(context, widget.imagePath);
        return;
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        img,
        Rect.fromLTRB(0, top, w, bottom),
        Rect.fromLTWH(0, 0, w, cropH),
        Paint(),
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(w.round(), cropH.round());
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      cropped.dispose();
      if (data == null) {
        if (mounted) Navigator.pop(context, widget.imagePath);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/ticket_crop_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(data.buffer.asUint8List());
      if (mounted) Navigator.pop(context, path);
    } catch (_) {
      if (mounted) Navigator.pop(context, widget.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final img = _image;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: GradientAppBar(
        title: const Text('Recortar ticket'),
        actions: [
          TextButton(
            onPressed:
                _busy ? null : () => Navigator.pop(context, widget.imagePath),
            child: const Text('Usar entera',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: img == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Arrastra las guías para dejar dentro solo los productos '
                    'y quitar la cabecera y el pie del ticket.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[300], fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: img.width / img.height,
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          final hh = c.maxHeight;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(File(widget.imagePath),
                                    fit: BoxFit.fill),
                              ),
                              // Sombra zona superior descartada
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: _top * hh,
                                child: Container(color: Colors.black54),
                              ),
                              // Sombra zona inferior descartada
                              Positioned(
                                left: 0,
                                right: 0,
                                top: _bottom * hh,
                                bottom: 0,
                                child: Container(color: Colors.black54),
                              ),
                              _guide(
                                top: _top * hh,
                                color: cs.primary,
                                onDrag: (dy) => setState(() {
                                  _top = (_top + dy / hh)
                                      .clamp(0.0, _bottom - 0.05);
                                }),
                              ),
                              _guide(
                                top: _bottom * hh,
                                color: cs.primary,
                                onDrag: (dy) => setState(() {
                                  _bottom = (_bottom + dy / hh)
                                      .clamp(_top + 0.05, 1.0);
                                }),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _confirm,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.crop),
                        label: const Text('Recortar y leer'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _guide({
    required double top,
    required Color color,
    required ValueChanged<double> onDrag,
  }) {
    const barH = 36.0;
    return Positioned(
      left: 0,
      right: 0,
      top: top - barH / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
        child: SizedBox(
          height: barH,
          child: Center(
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.85),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drag_handle, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
