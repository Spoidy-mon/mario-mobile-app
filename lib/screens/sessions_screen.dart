import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../widgets/session_tile.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/start_session_dialog.dart';
import '../widgets/end_session_dialog.dart';
import '../theme/app_colors.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<DashboardProvider>().stats;
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
        title: const Text('Sessions',
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
                          onTap: pc.isActive
                              ? () => showEndSessionDialog(
                                    context,
                                    firebaseNode: 'pcs/${pc.firebaseKey}',
                                    deviceName: pc.name,
                                    customerName: pc.customerName,
                                    timeLeft: pc.timeStr,
                                  )
                              : () => showStartSessionDialog(
                                    context,
                                    title: 'Start Session · ${pc.name}',
                                    firebaseNode: 'pcs/${pc.firebaseKey}',
                                    deviceName: pc.name,
                                    deviceType: SessionDeviceType.pc,
                                  ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          if (stats.wheel != null)
            _Section(
              title: '🏎  Racing Wheel',
              children: [
                FadeSlideIn(
                  delay: next(),
                  child: SessionTile(
                    label: stats.wheel!.name,
                    status: stats.wheel!.status,
                    isPaused: stats.wheel!.isPaused,
                    isLow: stats.wheel!.isLow,
                    timeStr: stats.wheel!.timeStr,
                    customerName: stats.wheel!.customerName,
                    paymentStatus: stats.wheel!.paymentStatus,
                    onTap: stats.wheel!.isActive
                        ? () => showEndSessionDialog(
                              context,
                              firebaseNode:
                                  'wheel_sessions/${stats.wheel!.firebaseKey}',
                              deviceName: stats.wheel!.name,
                              customerName: stats.wheel!.customerName,
                              timeLeft: stats.wheel!.timeStr,
                            )
                        : () => showStartSessionDialog(
                              context,
                              title: 'Start Session · Wheel',
                              firebaseNode: 'wheel_sessions/${stats.wheel!.firebaseKey}',
                              deviceName: stats.wheel!.name,
                              deviceType: SessionDeviceType.wheel,
                            ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          _Section(
            title: '🎮  PS5  (${stats.activePs5Sessions} active)',
            children: stats.ps5s
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
                          onTap: ps.isActive
                              ? () => showEndSessionDialog(
                                    context,
                                    firebaseNode: 'ps5_sessions/${ps.firebaseKey}',
                                    deviceName: 'PS5 #${ps.slot}',
                                    customerName: ps.customerName,
                                    timeLeft: ps.timeStr,
                                  )
                              : () => showStartSessionDialog(
                                    context,
                                    title: 'Start Session · PS5 #${ps.slot}',
                                    firebaseNode: 'ps5_sessions/${ps.firebaseKey}',
                                    deviceName: 'PS5 #${ps.slot}',
                                    deviceType: SessionDeviceType.ps5,
                                  ),
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