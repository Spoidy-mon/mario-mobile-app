import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../widgets/session_tile.dart';
import '../widgets/fade_slide_in.dart';
import '../theme/app_colors.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<DashboardProvider>().stats;
    final onlinePcs = stats.pcs.where((pc) => pc.status.toLowerCase() != 'offline').toList();
    final onlinePs5s = stats.ps5s.where((ps) => ps.status.toLowerCase() != 'offline').toList();
    int step = 0;
    Duration next() {
      final d = Duration(milliseconds: 50 * step);
      step++;
      return d;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Active Sessions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '🖥  PCs  (${stats.activePcSessions} active)',
            children: onlinePcs
                .map((pc) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FadeSlideIn(
                        delay: next(),
                        child: SessionTile(
                          label: pc.name,
                          status: pc.status,
                          isPaused: pc.isPaused,
                          isLow: pc.isLow,
                          timeStr: pc.timeStr,
                          customerName: pc.customerName,
                          paymentStatus: pc.paymentStatus,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _Section(
            title: '🎮  PS5  (${stats.activePs5Sessions} active)',
            children: onlinePs5s
                .map((ps) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FadeSlideIn(
                        delay: next(),
                        child: SessionTile(
                          label: 'PS5 #${ps.slot}',
                          status: ps.status,
                          isPaused: ps.isPaused,
                          isLow: false,
                          timeStr: ps.timeStr,
                          customerName: ps.customerName,
                          paymentStatus: ps.paymentStatus,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}