import 'package:flutter/material.dart';
import 'dart:math';

/// Demo page to preview the gauge (upward arc)
class BudgetGaugeDemo extends StatelessWidget {
  const BudgetGaugeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final double limit = 5000.0;
    final double spent = 55000.0; // 1100%

    return Scaffold(
      appBar: AppBar(title: const Text('Budget Gauge Demo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              BudgetGauge(
                limit: limit,
                spent: spent,
                size: 320,
                upwardArc: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Limit: ₹${limit.toStringAsFixed(0)} • Spent: ₹${spent.toStringAsFixed(0)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BudgetGauge extends StatelessWidget {
  final double limit;
  final double spent;
  final double size;
  final bool upwardArc;

  const BudgetGauge({
    super.key,
    required this.limit,
    required this.spent,
    this.size = 250,
    this.upwardArc = true,
  });

  @override
  Widget build(BuildContext context) {
    final double usedPercent = (limit > 0) ? (spent / limit) * 100.0 : 100.0;
    final bool over = usedPercent > 100.0;

    return SizedBox(
      width: size,
      child: Column(
        children: [
          // --- ARC + NEEDLE ---
          SizedBox(
            width: size,
            height: size * 0.55,
            child: CustomPaint(
              painter: _GaugePainter(
                usedPercent: usedPercent,
                upwardArc: upwardArc,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // --- LABELS ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: _GaugeLabels(),
          ),

          const SizedBox(height: 16),

          // --- BIG PERCENT BELOW LABELS ---
          Column(
            children: [
              Text(
                '${usedPercent.round()}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: over ? Colors.red.shade700 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                over ? 'Over budget' : 'Used',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: over ? Colors.red.shade600 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugeLabels extends StatelessWidget {
  const _GaugeLabels();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text('200%'),
        Text('100%'),
        Text('70%'),
        Text('0%'),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double usedPercent;
  final bool upwardArc;
  final double maxPercent = 200.0;

  _GaugePainter({required this.usedPercent, required this.upwardArc});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = upwardArc
        ? Offset(size.width / 2, size.height * 0.95)
        : Offset(size.width / 2, size.height * 0.05);

    final double radius = min(size.width * 0.35, size.height * 0.65);
    final double stroke = radius * 0.25;

    final double startAngle = upwardArc ? 0 : pi;
    final double fullSweep = upwardArc ? -pi : pi;

    final double greenTo = 70.0;
    final double orangeTo = 100.0;
    final double redTo = maxPercent;

    double percentToSweep(double p) => (p / maxPercent) * pi;

    Offset pointOnCircle(double angle, double r) =>
        Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));

    double angleForPercent(double p) {
      final sweep = percentToSweep(p);
      return upwardArc ? startAngle - sweep : startAngle + sweep;
    }

    // BACKGROUND
    final Paint bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep,
      false,
      bgPaint,
    );

    // ---- SEGMENTS ----
    void drawSegment(Color color, double fromP, double toP) {
      final double fromSweep = percentToSweep(fromP);
      final double toSweep = percentToSweep(toP);

      final double sweep =
          upwardArc ? -(toSweep - fromSweep) : (toSweep - fromSweep);

      final double segStart =
          upwardArc ? startAngle - fromSweep : startAngle + fromSweep;

      final Paint seg = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..isAntiAlias = true;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segStart,
        sweep,
        false,
        seg,
      );
    }

    drawSegment(Colors.green.shade600, 0.0, greenTo);
    drawSegment(Colors.orange.shade700, greenTo, orangeTo);
    drawSegment(Colors.red.shade700, orangeTo, redTo);

    // ---- TICKS ----
    final tickPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..isAntiAlias = true;

    // CORRECT ORDER: 200%, 100%, 70%, 0%
    for (double p in [redTo, orangeTo, greenTo, 0.0]) {
      final angle = angleForPercent(p);
      final inner = pointOnCircle(angle, radius - stroke / 2);
      final outer = pointOnCircle(angle, radius + stroke / 2 + 8);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // ---- NEEDLE ----
    final double clamped = usedPercent.clamp(0.0, maxPercent);
    final double needleAngle = angleForPercent(clamped);

    final double needleLength = radius - stroke - 8;
    final Offset needleEnd = pointOnCircle(needleAngle, needleLength);

    final needlePaint = Paint()
      ..color = usedPercent > 100 ? Colors.red.shade700 : Colors.black87
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(center, needleEnd, needlePaint);

    // PIVOT
    canvas.drawCircle(center, 6, Paint()..color = Colors.grey.shade800);
    canvas.drawCircle(
      center.translate(0, upwardArc ? 10 : -10),
      4,
      Paint()..color = Colors.grey.shade400,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.usedPercent != usedPercent ||
        oldDelegate.upwardArc != upwardArc;
  }
}
