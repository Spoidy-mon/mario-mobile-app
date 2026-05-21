import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../widgets/session_tile.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<DashboardProvider>().stats;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Active Sessions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '🖥  PCs  (${stats.activePcSessions} active)',
            children: stats.pcs
                .map((pc) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SessionTile(
                        label: pc.name,
                        status: pc.status,
                        isPaused: pc.isPaused,
                        isLow: pc.isLow,
                        timeStr: pc.timeStr,
                        customerName: pc.customerName,
                        paymentStatus: pc.paymentStatus,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _Section(
            title: '🎮  PS5  (${stats.activePs5Sessions} active)',
            children: stats.ps5s
                .map((ps) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SessionTile(
                        label: 'PS5 #${ps.slot}',
                        status: ps.status,
                        isPaused: ps.isPaused,
                        isLow: false,
                        timeStr: ps.timeStr,
                        customerName: ps.customerName,
                        paymentStatus: ps.paymentStatus,
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
