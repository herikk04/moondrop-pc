import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gaia.dart';

/// Gráfico da curva do EQ no estilo do app oficial: moldura clara, grade logarítmica
/// (20 Hz a 20 kHz), escala em dB à esquerda e curva branca.
class EqCurve extends StatelessWidget {
  const EqCurve({
    super.key,
    required this.bands,
    this.preGainDb = 0,
    this.height = 220,
    this.selected,
    this.showLegend = true,
  });

  final List<EqBand> bands;
  final double preGainDb;
  final double height;

  /// Índice da banda destacada (ponto maior com contorno branco).
  final int? selected;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (showLegend)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(left: 30, bottom: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF555555),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('——  ', style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('Personalizado', style: TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ),
      SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _CurvePainter(bands: bands, preGainDb: preGainDb, selected: selected),
        ),
      ),
    ]);
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.bands, required this.preGainDb, this.selected});

  final List<EqBand> bands;
  final double preGainDb;
  final int? selected;

  static const _fMin = 20.0, _fMax = 20000.0;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, bottom = 22.0, top = 4.0, right = 14.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    // escala vertical: +-12 dB, crescendo de 6 em 6 se a curva passar
    const n = 260;
    final values = <double>[];
    var maxAbs = 12.0;
    for (var i = 0; i < n; i++) {
      final f = _fMin * math.pow(_fMax / _fMin, i / (n - 1));
      final v = eqCurveDb(bands, f.toDouble()) + preGainDb;
      values.add(v);
      maxAbs = math.max(maxAbs, v.abs());
    }
    maxAbs = (maxAbs / 6).ceil() * 6.0;

    double xOf(double f) => left + w * (math.log(f / _fMin) / math.log(_fMax / _fMin));
    double yOf(double db) => top + h * (1 - (db + maxAbs) / (2 * maxAbs));

    final grid = Paint()
      ..color = const Color(0xFF5A5A5A)
      ..strokeWidth = 1;
    const style = TextStyle(color: Colors.white, fontSize: 12);

    void text(String t, Offset o, {bool centerX = false}) {
      final tp = TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, centerX ? Offset(o.dx - tp.width / 2, o.dy) : Offset(o.dx - tp.width, o.dy - tp.height / 2));
    }

    // horizontais (dB)
    for (var db = -maxAbs; db <= maxAbs + 0.01; db += 6) {
      final y = yOf(db);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      text('${db.round()}', Offset(left - 6, y));
    }
    // verticais: todas as marcas de 1-9 por década
    for (final dec in [10.0, 100.0, 1000.0, 10000.0]) {
      for (var m = 1; m <= 9; m++) {
        final f = dec * m;
        if (f < _fMin || f > _fMax) continue;
        canvas.drawLine(Offset(xOf(f), top), Offset(xOf(f), top + h), grid);
      }
    }
    canvas.drawLine(Offset(xOf(20000), top), Offset(xOf(20000), top + h), grid);
    for (final f in [20.0, 100, 1000, 10000, 20000]) {
      text(f >= 1000 ? '${(f / 1000).round()}k' : '${f.round()}',
          Offset(xOf(f.toDouble()), top + h + 4),
          centerX: true);
    }

    // curva
    final path = Path();
    for (var i = 0; i < n; i++) {
      final f = _fMin * math.pow(_fMax / _fMin, i / (n - 1));
      final p = Offset(xOf(f.toDouble()), yOf(values[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);

    // moldura
    canvas.drawRect(
        Rect.fromLTWH(left, top, w, h),
        Paint()
          ..color = const Color(0xFFD0D0D0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4);

    // pontos das bandas
    for (final b in bands) {
      final f = b.freqHz.toDouble().clamp(_fMin, _fMax);
      final c = Offset(xOf(f), yOf(eqCurveDb(bands, f) + preGainDb));
      final sel = b.index == selected;
      canvas.drawCircle(c, sel ? 7 : 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
          c,
          sel ? 7 : 4.5,
          Paint()
            ..color = const Color(0xFF222222)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => true;
}
