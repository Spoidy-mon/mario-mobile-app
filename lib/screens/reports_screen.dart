import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../widgets/mini_pie_chart.dart';
import '../widgets/fade_slide_in.dart';
import '../theme/app_colors.dart';


enum _Range { week, month, all, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Range _range = _Range.week;
  DateTimeRange? _customRange;

  String _fmt(double v) =>
      '₹${v.abs() >= 1000 ? '${(v.abs() / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0)}';

  DateTime get _start {
    final now = DateTime.now();
    switch (_range) {
      case _Range.week:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case _Range.month:
        return DateTime(now.year, now.month, 1);
      case _Range.all:
        return DateTime(2000);
      case _Range.custom:
        return _customRange?.start ?? DateTime(now.year, now.month, now.day);
    }
  }

  DateTime get _end {
    if (_range == _Range.custom && _customRange != null) {
      // end date is inclusive of the whole day
      return _customRange!.end.add(const Duration(days: 1));
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.card,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppColors.bg,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _range = _Range.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final report = prov.computeReport(_start, _end);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Reports',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _RangeChip(
                  label: 'This Week',
                  selected: _range == _Range.week,
                  onTap: () => setState(() => _range = _Range.week)),
              const SizedBox(width: 8),
              _RangeChip(
                  label: 'This Month',
                  selected: _range == _Range.month,
                  onTap: () => setState(() => _range = _Range.month)),
              const SizedBox(width: 8),
              _RangeChip(
                  label: 'All Time',
                  selected: _range == _Range.all,
                  onTap: () => setState(() => _range = _Range.all)),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickCustomRange,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _range == _Range.custom ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _range == _Range.custom ? AppColors.primary : Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 15,
                      color: _range == _Range.custom ? Colors.white : Colors.white54),
                  const SizedBox(width: 6),
                  Text(
                    _range == _Range.custom && _customRange != null
                        ? '${_customRange!.start.day}/${_customRange!.start.month} → ${_customRange!.end.day}/${_customRange!.end.month}'
                        : 'Custom Date Range',
                    style: TextStyle(
                        color: _range == _Range.custom ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Revenue',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_fmt(report.totalRevenue),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniStat(label: 'Cash', value: _fmt(report.cashTotal)),
                      const SizedBox(width: 10),
                      _MiniStat(label: 'UPI', value: _fmt(report.upiTotal)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('REVENUE BREAKDOWN',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),

          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration:
                  BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: report.totalRevenue <= 0
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No revenue in this range',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                    )
                  : Row(
                      children: [
                        MiniPieChart(
                          size: 120,
                          slices: [
                            PieSlice(label: 'PC', value: report.pcRevenue, color: AppColors.primary),
                            PieSlice(label: 'PS5', value: report.ps5Revenue, color: AppColors.purple),
                            PieSlice(
                                label: 'Canteen', value: report.canteenRevenue, color: AppColors.amber),
                            PieSlice(
                                label: 'Membership',
                                value: report.membershipRevenue,
                                color: AppColors.cyan),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PieLegend(
                            total: report.totalRevenue,
                            slices: [
                              PieSlice(label: 'PC', value: report.pcRevenue, color: AppColors.primary),
                              PieSlice(label: 'PS5', value: report.ps5Revenue, color: AppColors.purple),
                              PieSlice(
                                  label: 'Canteen',
                                  value: report.canteenRevenue,
                                  color: AppColors.amber),
                              PieSlice(
                                  label: 'Membership',
                                  value: report.membershipRevenue,
                                  color: AppColors.cyan),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Row(
              children: [
                Expanded(
                    child: _CountCard(
                        label: 'Gaming Orders',
                        value: report.gamingTransactions,
                        color: AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(
                    child: _CountCard(
                        label: 'Canteen Orders',
                        value: report.canteenTransactions,
                        color: AppColors.amber)),
                const SizedBox(width: 10),
                Expanded(
                    child: _CountCard(
                        label: 'New Members',
                        value: report.membershipTransactions,
                        color: AppColors.cyan)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primary : Colors.white12),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text('$label $value',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _CountCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
        ],
      ),
    );
  }
}