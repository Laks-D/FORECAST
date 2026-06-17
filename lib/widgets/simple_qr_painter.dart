import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

class SimpleQr extends StatelessWidget {
  const SimpleQr({super.key, required this.data, this.size = 200.0});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    try {
      final qr = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
      final image = QrImage(qr);
      return CustomPaint(
        size: Size.square(size),
        painter: _QrPainter(image: image),
      );
    } catch (_) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: Text('Invalid QR data', style: Theme.of(context).textTheme.bodySmall)),
      );
    }
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter({required this.image});

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final modules = image.moduleCount;
    final moduleSize = size.width / modules;

    // white background
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    paint.color = Colors.black;
    for (var x = 0; x < modules; x++) {
      for (var y = 0; y < modules; y++) {
        if (image.isDark(y, x)) {
          final rect = Rect.fromLTWH(x * moduleSize, y * moduleSize, moduleSize, moduleSize);
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => false;
}
