import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/app_page_route.dart';
import 'sessions_screen.dart';
import 'dues_screen.dart';
import 'ledger_screen.dart';
import 'stock_screen.dart';
import 'members_screen.dart';
import 'reports_screen.dart';
import 'diagnostics_screen.dart';
import 'settings_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/password_gate_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _money(double v) {
    final a = v.abs();
    final s = v < 0 ? '-' : '';
    if (a >= 100000) return '$s₹${(a / 100000).toStringAsFixed(1)}L';
    if (a >= 1000) return '$s₹${(a / 1000).toStringAsFixed(1)}k';
    return '$s₹${a.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();

    if (prov.loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary),
          ),
        ),
      );
    }

    if (prov.error != null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 40, color: AppColors.textMuted),
                SizedBox(height: 14),
                Text(
                  "Can't reach the café data",
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Check the internet connection and pull down to retry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final s = prov.stats;
    final l = prov.ledger;

    // Staggered entrance — each block appears just after the last.
    int step = 0;
    Duration next() => Duration(milliseconds: 55 * step++);

    final lowStock = prov.stock.where((i) => i.isLow || i.isOut).length;
    final activeMembers = prov.members.where((m) => m.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.cafeeName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: AppColors.green, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.totalActive == 0
                                ? 'No one playing right now'
                                : '${s.totalActive} playing right now',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _IconBtn(
                  icon: Icons.tune_rounded,
                  onTap: () => Navigator.push(context,
                      AppPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const SizedBox(width: 8),
                _IconBtn(
                  icon: Icons.storage_rounded,
                  onTap: () async {
                    final unlocked = await requirePassword(
                      context,
                      title: 'Firebase Diagnostics',
                      expectedPassword: prov.expensePassword,
                      subtitle: 'Enter the password to view raw database contents.',
                    );
                    if (unlocked && context.mounted) {
                      Navigator.push(context,
                          AppPageRoute(builder: (_) => const DiagnosticsScreen()));
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ── Hero: today's earnings ────────────────────────────────
            // The single loudest element on the screen. Everything else is
            // deliberately quieter so this reads first, every time.
            FadeSlideIn(
              delay: next(),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EARNED TODAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money(s.todayTotalRevenue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.8,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _HeroSplit(
                            label: 'Cash', value: _money(s.todayCash)),
                        Container(
                          width: 1,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: Colors.white24,
                        ),
                        _HeroSplit(label: 'UPI', value: _money(s.todayUpi)),
                        Container(
                          width: 1,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: Colors.white24,
                        ),
                        _HeroSplit(
                            label: 'Gaming',
                            value: _money(s.todayGamingRevenue)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),
            const _SectionLabel('Right now'),
            const SizedBox(height: 10),

            FadeSlideIn(
              delay: next(),
              child: StatCard(
                icon: Icons.sports_esports_rounded,
                label: 'Sessions running',
                value: '${s.totalActive}',
                color: s.totalActive > 0
                    ? AppColors.green
                    : AppColors.textMuted,
                sub: '${s.activePcSessions} PC · ${s.activePs5Sessions} PS5',
                onTap: () => Navigator.push(context,
                    AppPageRoute(builder: (_) => const SessionsScreen())),
              ),
            ),
            const SizedBox(height: 9),

            FadeSlideIn(
              delay: next(),
              child: StatCard(
                icon: Icons.receipt_long_rounded,
                label: 'Unpaid dues',
                value: _money(s.pendingDuesTotal),
                color: s.pendingDuesCount > 0
                    ? AppColors.red
                    : AppColors.textMuted,
                sub: s.pendingDuesCount == 0
                    ? 'All settled'
                    : '${s.pendingDuesCount} customers owe money',
                alert: s.pendingDuesCount > 0,
                onTap: () => Navigator.push(context,
                    AppPageRoute(builder: (_) => const DuesScreen())),
              ),
            ),
            const SizedBox(height: 9),

            FadeSlideIn(
              delay: next(),
              child: StatCard(
                icon: Icons.inventory_2_rounded,
                label: 'Canteen stock',
                value: lowStock > 0 ? '$lowStock' : 'OK',
                color: lowStock > 0 ? AppColors.amber : AppColors.green,
                sub: lowStock > 0
                    ? 'Items low or finished — reorder soon'
                    : '${prov.stock.length} items stocked',
                alert: lowStock > 0,
                onTap: () => Navigator.push(context,
                    AppPageRoute(builder: (_) => const StockScreen())),
              ),
            ),

            const SizedBox(height: 22),
            const _SectionLabel('Money'),
            const SizedBox(height: 10),

            FadeSlideIn(
              delay: next(),
              child: StatCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Cash in counter',
                value: _money(l.counterCash),
                color: l.counterCash < 0 ? AppColors.red : AppColors.green,
                sub: l.isMarioNegative
                    ? 'Café is short — partners need to add funds'
                    : 'Split three ways after expenses',
                alert: l.isMarioNegative,
                onTap: () => Navigator.push(context,
                    AppPageRoute(builder: (_) => const LedgerScreen())),
              ),
            ),
            const SizedBox(height: 9),

            FadeSlideIn(
              delay: next(),
              child: StatCard(
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                value: 'Open',
                color: AppColors.primary,
                sub: 'Week, month, or any date range',
                onTap: () => Navigator.push(context,
                    AppPageRoute(builder: (_) => const ReportsScreen())),
              ),
            ),

            const SizedBox(height: 22),
            const _SectionLabel('Café'),
            const SizedBox(height: 10),

            FadeSlideIn(
              delay: next(),
              child: StatCard(
                icon: Icons.card_membership_rounded,
                label: 'Members',
                value: '$activeMembers',
                color: AppColors.purple,
                sub: '${prov.members.length} enrolled in total',
                onTap: () => Navigator.push(context,
                    AppPageRoute(builder: (_) => const MembersScreen())),
              ),
            ),
            const SizedBox(height: 9),

            FadeSlideIn(
              delay: next(),
              child: StatCard(
                icon: Icons.bolt_rounded,
                label: 'Electricity',
                value: _money(s.electricityCost30d),
                color: AppColors.cyan,
                sub:
                    'Last 30 days · ${s.electricityUnits30d.toStringAsFixed(0)} units at ₹${s.electricityRate.toStringAsFixed(0)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _HeroSplit extends StatelessWidget {
  final String label;
  final String value;
  const _HeroSplit({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3)),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}