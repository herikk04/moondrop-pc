import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gaia.dart';

/// Gráfico da curva de resposta do EQ (20 Hz a 20 kHz, escala log) com os pontos das bandas.
class EqCurve extends StatelessWidget {
  const EqCurve({super.key, required this.bands, this.preGainDb = 0, this.height = 170});

  final List<EqBand> bands;
  final double preGainDb;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CurvePainter(
          bands: bands,
          preGainDb: preGainDb,
          line: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.bands, required this.preGainDb, required this.line});

  final List<EqBand> bands;
  final double preGainDb;
  final Color line;

  static const _fMin = 20.0, _fMax = 20000.0;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, bottom = 18.0, top = 6.0, right = 6.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    // escala vertical: +-12 dB por padrão, cresce se a curva passar disso
    var maxAbs = 12.0;
    final pts = <Offset>[];
    const n = 240;
    final values = <double>[];
    for (var i = 0; i < n; i++) {
      final f = _fMin * math.pow(_fMax / _fMin, i / (n - 1));
      final v = eqCurveDb(bands, f.toDouble());
      values.add(v);
      maxAbs = math.max(maxAbs, v.abs());
    }
    maxAbs = (maxAbs / 6).ceil() * 6.0;

    double xOf(double f) => left + w * (math.log(f / _fMin) / math.log(_fMax / _fMin));
    double yOf(double db) => top + h * (1 - (db + maxAbs) / (2 * maxAbs));

    final grid = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    final zero = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1;
    const style = TextStyle(color: Colors.white38, fontSize: 10);

    void label(String t, Offset o, {bool centerX = false}) {
      final tp = TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, centerX ? Offset(o.dx - tp.width / 2, o.dy) : Offset(o.dx - tp.width, o.dy - tp.height / 2));
    }

    // linhas horizontais (dB)
    for (var db = -maxAbs; db <= maxAbs + 0.01; db += 6) {
      final y = yOf(db);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), db == 0 ? zero : grid);
      label('${db.round()}', Offset(left - 4, y));
    }
    // linhas verticais (Hz)
    for (final f in [20.0, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]) {
      final x = xOf(f.toDouble());
      canvas.drawLine(Offset(x, top), Offset(x, top + h), grid);
      if ([20.0, 100, 1000, 10000, 20000].contains(f)) {
        label(f >= 1000 ? '${(f / 1000).round()}k' : '${f.round()}', Offset(x, top + h + 3), centerX: true);
      }
    }

    // curva
    final path = Path();
    for (var i = 0; i < n; i++) {
      final f = _fMin * math.pow(_fMax / _fMin, i / (n - 1));
      pts.add(Offset(xOf(f.toDouble()), yOf(values[i])));
    }
    path.moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, yOf(0))
      ..lineTo(pts.first.dx, yOf(0))
      ..close();
    canvas.drawPath(fill, Paint()..color = line.withValues(alpha: 0.16));
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);

    // pontos das bandas (na curva total)
    for (final b in bands) {
      final f = b.freqHz.toDouble().clamp(_fMin, _fMax);
      final y = yOf(eqCurveDb(bands, f));
      canvas.drawCircle(Offset(xOf(f), y), 4.5, Paint()..color = line);
      canvas.drawCircle(Offset(xOf(f), y), 4.5,
          Paint()
            ..color = const Color(0xFF0E1013)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => true;
}
