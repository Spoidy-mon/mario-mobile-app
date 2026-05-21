import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/session_tile.dart';
import 'sessions_screen.dart';
import 'dues_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _fmt(double v) => '₹${v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();

    if (prov.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎮', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Color(0xFF6366F1)),
              SizedBox(height: 12),
              Text('Loading dashboard…',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    if (prov.error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'Firebase error:\n${prov.error}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final s = prov.stats;
    final activeSessions = s.pcs.where((p) => p.isActive).take(4).toList();
    final activePs5 = s.ps5s.where((p) => p.isActive).take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: RefreshIndicator(
        onRefresh: () async {},
        color: const Color(0xFF6366F1),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ─────────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: const Color(0xFF0D0D1A),
              expandedHeight: 100,
              floating: true,
              snap: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.cafeeName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${s.totalActive} active · Live dashboard',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Live indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF22C55E).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            const Text('LIVE',
                                style: TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Today's earnings section ─────────────────────────
                  _SectionLabel(label: "TODAY'S EARNINGS"),
                  const SizedBox(height: 10),

                  // Big total card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Today',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              _fmt(s.todayTotalRevenue),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _PayChip(
                                label: '💵 Cash',
                                value: _fmt(s.todayCash),
                                color: const Color(0xFF22C55E)),
                            const SizedBox(height: 8),
                            _PayChip(
                                label: '📱 UPI',
                                value: _fmt(s.todayUpi),
                                color: const Color(0xFFF59E0B)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Gaming + Canteen row
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: '🖥',
                          label: 'Gaming',
                          value: _fmt(s.todayGamingRevenue),
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: '🛒',
                          label: 'Canteen',
                          value: _fmt(s.todayCanteenRevenue),
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Quick stats row ──────────────────────────────────
                  _SectionLabel(label: 'QUICK STATS'),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: '⚡',
                          label: 'Active Sessions',
                          value: '${s.totalActive}',
                          color: const Color(0xFF22C55E),
                          sub: '${s.activePcSessions} PC · ${s.activePs5Sessions} PS5',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const SessionsScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: '💳',
                          label: 'Pending Dues',
                          value: _fmt(s.pendingDuesTotal),
                          color: const Color(0xFFEF4444),
                          sub: '${s.pendingDuesCount} unpaid',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const DuesScreen())),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Electricity card
                  StatCard(
                    icon: '🔌',
                    label: 'Electricity Cost (30 days)',
                    value: _fmt(s.electricityCost30d),
                    color: const Color(0xFF06B6D4),
                    sub:
                        '${s.electricityUnits30d.toStringAsFixed(1)} units · ₹${s.electricityRate.toStringAsFixed(0)}/unit · Metre: ${s.latestMetreReading.toStringAsFixed(0)}',
                  ),

                  // ── Live sessions preview ────────────────────────────
                  if (activeSessions.isNotEmpty || activePs5.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _SectionLabel(label: 'LIVE SESSIONS'),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SessionsScreen())),
                          child: const Text('See all',
                              style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...activeSessions.map((pc) => Padding(
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
                        )),
                    ...activePs5.map((ps) => Padding(
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
                        )),
                  ],

                  // ── Pending dues preview ─────────────────────────────
                  if (s.dues.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _SectionLabel(label: 'PENDING DUES'),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DuesScreen())),
                          child: const Text('See all',
                              style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...s.dues.take(3).map((due) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFEF4444).withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  due.customerName.isNotEmpty
                                      ? due.customerName
                                      : 'Unknown',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                Text('· ${due.pcName}',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12)),
                                const Spacer(),
                                Text(
                                  '₹${due.amount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2),
    );
  }
}

class _PayChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PayChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
