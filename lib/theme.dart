import 'package:flutter/material.dart';

class ScannerTheme {
  static const Color cyan = Color(0xFF25D0C5);
  static const Color blue = Color(0xFF5B8CFF);
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080B12),
        colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      );
}

class ScanFrame extends StatelessWidget {
  const ScanFrame({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => SizedBox(width: 250, height: 250, child: CustomPaint(painter: _FramePainter()));
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ScannerTheme.cyan..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const length = 34.0;
    final path = Path()
      ..moveTo(4, length)..lineTo(4, 4)..lineTo(length, 4)
      ..moveTo(size.width - length, 4)..lineTo(size.width - 4, 4)..lineTo(size.width - 4, length)
      ..moveTo(4, size.height - length)..lineTo(4, size.height - 4)..lineTo(length, size.height - 4)
      ..moveTo(size.width - length, size.height - 4)..lineTo(size.width - 4, size.height - 4)..lineTo(size.width - 4, size.height - length);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}