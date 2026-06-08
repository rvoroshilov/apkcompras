import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _detected = false;
  String? _lastCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear código'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.torchState,
              builder: (_, state, __) => Icon(
                state == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scanning overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _detected ? Colors.green : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Corner decorations
          ..._buildCorners(),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_lastCode != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Detectado: $_lastCode',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Enfoca el código de barras',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),
          // Manual input option
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: _manualInput,
                child: const Text(
                  'Introducir manualmente',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        setState(() {
          _detected = true;
          _lastCode = code;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context, code);
        });
        return;
      }
    }
  }

  Future<void> _manualInput() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de barras'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Introduce el código',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      Navigator.pop(context, result);
    }
  }

  List<Widget> _buildCorners() {
    const size = 24.0;
    const color = Colors.white;
    const thickness = 3.0;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final cx = sw / 2;
    final cy = sh / 2;
    final half = 130.0;

    Widget corner(double top, double left, bool flipH, bool flipV) {
      return Positioned(
        top: top,
        left: left,
        child: Transform.scale(
          scaleX: flipH ? -1 : 1,
          scaleY: flipV ? -1 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CornerPainter(color: color, thickness: thickness),
            ),
          ),
        ),
      );
    }

    return [
      corner(cy - half, cx - half, false, false),
      corner(cy - half, cx + half - size, true, false),
      corner(cy + half - size, cx - half, false, true),
      corner(cy + half - size, cx + half - size, true, true),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;

  const _CornerPainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => false;
}
