import 'dart:math' as math;
import 'package:flutter/material.dart';

class PieSlice {
  final String label;
  final double value;
  final Color color;
  const PieSlice({required this.label, required this.value, required this.color});
}

class MiniPieChart extends StatelessWidget {
  final List<PieSlice> slices;
  final double size;
  const MiniPieChart({super.key, required this.slices, this.size = 140});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + (s.value > 0 ? s.value : 0));
    return SizedBox(
      width: size,
      height: size,
      child: total <= 0
          ? Center(
              child: Text('No data yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
            )
          : CustomPaint(
              size: Size(size, size),
              painter: _PiePainter(slices: slices, total: total),
            ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<PieSlice> slices;
  final double total;
  _PiePainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double startAngle = -math.pi / 2;
    final strokeWidth = size.width * 0.22;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweep - 0.03, // tiny gap between slices
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.total != total;
  }
}

class PieLegend extends StatelessWidget {
  final List<PieSlice> slices;
  final double total;
  const PieLegend({super.key, required this.slices, required this.total});

  String _fmt(double v) =>
      '₹${v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: slices.map((s) {
        final pct = total > 0 ? (s.value / total * 100) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(s.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text('${_fmt(s.value)} · ${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: s.color, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      }).toList(),
    );
  }
}