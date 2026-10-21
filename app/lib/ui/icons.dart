import 'package:flutter/material.dart';

/// Ícones desenhados à mão no estilo do app oficial (anel com marca).
enum AncGlyph { transparency, noise, off }

class AncIcon extends StatelessWidget {
  const AncIcon(this.glyph, {super.key, required this.color, this.size = 36});

  final AncGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _AncPainter(glyph, color));
}

class _AncPainter extends CustomPainter {
  _AncPainter(this.glyph, this.color);

  final AncGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 2.5;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4;
    canvas.drawCircle(c, r, ring);
    final fill = Paint()..color = color;
    switch (glyph) {
      case AncGlyph.transparency:
        break;
      case AncGlyph.noise:
        final p = Path()
          ..moveTo(c.dx, c.dy + 1)
          ..lineTo(c.dx + 4.2, c.dy + 8)
          ..lineTo(c.dx - 4.2, c.dy + 8)
          ..close();
        canvas.drawPath(p, fill);
      case AncGlyph.off:
        canvas.drawLine(Offset(c.dx, c.dy - 8), Offset(c.dx, c.dy + 1.5),
            ring..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _AncPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// Bateria em formato de pilha com preenchimento proporcional (como no app oficial).
class BatteryGlyph extends StatelessWidget {
  const BatteryGlyph({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(62, 26), painter: _BatteryPainter(percent));
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter(this.percent);

  final int percent;

  @override
  void paint(Canvas canvas, Size s) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, s.width - 8, s.height - 2), const Radius.circular(5));
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(body, stroke);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width - 5, s.height / 2 - 4, 4, 8), const Radius.circular(2)),
        Paint()..color = Colors.white);
    final w = (s.width - 14) * (percent.clamp(0, 100) / 100);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(4, 4, w, s.height - 8), const Radius.circular(3)),
        Paint()..color = percent <= 15 ? const Color(0xFFFF8A80) : Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter old) => old.percent != percent;
}

/// Ilustração simples de um par de fones (sem usar imagens do fabricante).
class EarbudsArt extends StatelessWidget {
  const EarbudsArt({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(height * 1.5, height), painter: _EarbudsPainter());
}

class _EarbudsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    void bud(double cx, bool mirror) {
      final sign = mirror ? -1.0 : 1.0;
      final headC = Offset(cx - sign * s.width * 0.03, s.height * 0.32);
      final r = s.height * 0.22;
      final white = Paint()..color = const Color(0xFFF2F2F2);
      final shade = Paint()..color = const Color(0xFFD6D6D6);
      // haste
      final stem = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + sign * r * 0.55, s.height * 0.62),
              width: r * 0.62,
              height: s.height * 0.62),
          const Radius.circular(5));
      canvas.drawRRect(stem, white);
      // detalhes laranja
      final stripe = Paint()
        ..color = const Color(0xFFE8892B)
        ..strokeWidth = 2;
      for (var i = 0; i < 7; i++) {
        final y = s.height * 0.46 + i * 6.0;
        canvas.drawLine(Offset(stem.left + 4, y), Offset(stem.right - 4, y), stripe);
      }
      // cabeça
      canvas.drawCircle(headC, r, white);
      canvas.drawCircle(headC.translate(sign * -r * 0.15, r * 0.1), r * 0.72, shade);
    }

    bud(s.width * 0.3, false);
    bud(s.width * 0.7, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
