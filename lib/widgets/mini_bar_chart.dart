import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BarItem {
  final String label;
  final double value;
  final Color color;
  const BarItem({required this.label, required this.value, required this.color});
}

class MiniBarChart extends StatelessWidget {
  final List<BarItem> items;
  final double height;
  const MiniBarChart({super.key, required this.items, this.height = 150});

  String _fmt(double v) =>
      '₹${v.abs() >= 1000 ? '${(v.abs() / 1000).toStringAsFixed(1)}k' : v.abs().toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final maxAbs = items.fold<double>(
        1, (m, i) => i.value.abs() > m ? i.value.abs() : m);
    final barArea = height - 42;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final barHeight = barArea <= 0
              ? 4.0
              : ((item.value.abs() / maxAbs) * barArea).clamp(4.0, barArea);
          final isNeg = item.value < 0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _fmt(item.value),
                    style: TextStyle(
                        color: isNeg ? AppColors.red : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isNeg ? AppColors.red : item.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}