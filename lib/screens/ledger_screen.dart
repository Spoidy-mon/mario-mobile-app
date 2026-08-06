import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../services/firebase_service.dart';
import '../services/ledger_model.dart';
import '../widgets/mini_pie_chart.dart';
import '../widgets/mini_bar_chart.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/password_gate_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_snackbar.dart';

String _fmt(double v) {
  final sign = v < 0 ? '-' : '';
  final av = v.abs();
  return '$sign₹${av >= 1000 ? '${(av / 1000).toStringAsFixed(1)}k' : av.toStringAsFixed(0)}';
}

Future<Map<String, dynamic>?> _showAmountDialog(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Confirm',
  Color confirmColor = AppColors.primary,
  bool showSubject = false,
  String? helperText,
}) {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (helperText != null) ...[
                  Text(helperText,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 12),
                ],
                if (showSubject) ...[
                  TextField(
                    controller: noteCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: appInputDecoration('What is this for?'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: appInputDecoration('Amount (₹)'),
                  ),
                ] else ...[
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: appInputDecoration('Amount (₹)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: appInputDecoration('Note (optional)'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                if (showSubject && noteCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, {
                  'amount': amount,
                  'note': noteCtrl.text.trim(),
                });
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      });
    },
  );
}

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  Future<void> _addExpense(BuildContext context) async {
    final res = await _showAmountDialog(
      context,
      title: 'Add Mario Gaming Expense',
      confirmLabel: 'Add Expense',
      confirmColor: AppColors.red,
      showSubject: true,
      helperText: 'This is subtracted from counter cash and from the profit pool.',
    );
    if (res == null) return;
    if (!context.mounted) return;
    final expensePwd = context.read<DashboardProvider>().expensePassword;
    final unlocked = await requirePassword(
      context,
      title: 'Mario Gaming Expenses',
      expectedPassword: expensePwd,
      subtitle: 'This action is protected — enter the expense password.',
    );
    if (!unlocked) return;
    try {
      await FirebaseService.addExpense(
        category: res['note'] as String,
        amount: res['amount'] as double,
        note: '',
      );
      if (context.mounted) showAppSnackbar(context, 'Expense added');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _withdraw(BuildContext context, PartnerInfo p) async {
    final res = await _showAmountDialog(
      context,
      title: 'Withdraw · ${p.name}',
      confirmLabel: 'Withdraw',
      confirmColor: AppColors.amber,
      helperText: 'Current balance: ${_fmt(p.balance)}. Taking more than this pushes ${p.name} negative.',
    );
    if (res == null) return;
    if (!context.mounted) return;
    final partnerPwd = context.read<DashboardProvider>().partnerPasswords[p.id] ?? '';
    final unlocked = await requirePassword(
      context,
      title: p.name,
      expectedPassword: partnerPwd,
      subtitle: 'Enter ${p.name}\'s password to withdraw.',
    );
    if (!unlocked) return;
    try {
      await FirebaseService.addWithdrawal(
        partnerId: p.id,
        partnerName: p.name,
        amount: res['amount'] as double,
        note: res['note'] as String,
      );
      if (context.mounted) showAppSnackbar(context, 'Withdrawal recorded for ${p.name}');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _repay(BuildContext context, PartnerInfo p) async {
    final res = await _showAmountDialog(
      context,
      title: 'Repay · ${p.name}',
      confirmLabel: 'Repay',
      confirmColor: AppColors.green,
      helperText: '${p.name} pays cash back into the counter against their own balance only.',
    );
    if (res == null) return;
    if (!context.mounted) return;
    final partnerPwd = context.read<DashboardProvider>().partnerPasswords[p.id] ?? '';
    final unlocked = await requirePassword(
      context,
      title: p.name,
      expectedPassword: partnerPwd,
      subtitle: 'Enter ${p.name}\'s password to repay.',
    );
    if (!unlocked) return;
    try {
      await FirebaseService.addRepayment(
        partnerId: p.id,
        partnerName: p.name,
        amount: res['amount'] as double,
        note: res['note'] as String,
      );
      if (context.mounted) showAppSnackbar(context, 'Repayment recorded for ${p.name}');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _contribute(BuildContext context, List<PartnerInfo> partners) async {
    String selectedId = partners.first.id;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Cover Mario Gaming Deficit',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mario Gaming is running a deficit. Any partner can add funds '
                  'to bring the business account back to positive.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: Colors.white),
                  decoration: appInputDecoration('Contributing Partner'),
                  items: partners
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedId = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: appInputDecoration('Amount (₹)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: appInputDecoration('Note (optional)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(ctx, {
                    'partnerId': selectedId,
                    'amount': amount,
                    'note': noteCtrl.text.trim(),
                  });
                },
                child: const Text('Add Funds'),
              ),
            ],
          );
        });
      },
    );

    if (res == null) return;
    if (!context.mounted) return;
    final partner = partners.firstWhere((p) => p.id == res['partnerId']);
    final partnerPwd = context.read<DashboardProvider>().partnerPasswords[partner.id] ?? '';
    final unlocked = await requirePassword(
      context,
      title: partner.name,
      expectedPassword: partnerPwd,
      subtitle: 'Enter ${partner.name}\'s password to contribute.',
    );
    if (!unlocked) return;
    try {
      await FirebaseService.addContribution(
        partnerId: partner.id,
        partnerName: partner.name,
        amount: res['amount'] as double,
        note: res['note'] as String,
      );
      if (context.mounted) showAppSnackbar(context, 'Funds added by ${partner.name}');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final l = prov.ledger;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Partner Ledger',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Counter cash + Mario Gaming balance ─────────────────────
          FadeSlideIn(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Counter Cash',
                    value: _fmt(l.counterCash),
                    color: l.counterCash < 0 ? AppColors.red : AppColors.green,
                    icon: '💵',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Mario Gaming',
                    value: _fmt(l.marioGamingBalance),
                    color: l.isMarioNegative ? AppColors.red : AppColors.primary,
                    icon: '🎮',
                  ),
                ),
              ],
            ),
          ),

          if (l.isMarioNegative) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mario Gaming is in deficit. Any partner can add funds.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _contribute(context, l.partners),
                    child: const Text('Add Funds', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Expenses button ──────────────────────────────────────────
          Row(
            children: [
              const _SectionLabel(label: 'MARIO GAMING EXPENSES'),
              const Spacer(),
              GestureDetector(
                onTap: () => _addExpense(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: AppColors.red),
                      SizedBox(width: 4),
                      Text('Add Expense',
                          style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Expenses (all-time)',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(_fmt(l.totalExpenses),
                          style: const TextStyle(
                              color: AppColors.red, fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                if (l.totalContributions > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Contributions',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(_fmt(l.totalContributions),
                          style: const TextStyle(
                              color: AppColors.cyan, fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Income breakdown chart ───────────────────────────────────
          const _SectionLabel(label: 'INCOME BREAKDOWN'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
            child: l.totalIncome <= 0
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No income recorded yet',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  )
                : Row(
                    children: [
                      MiniPieChart(
                        size: 120,
                        slices: [
                          PieSlice(label: 'Gaming', value: l.gamingIncome, color: AppColors.primary),
                          PieSlice(label: 'Canteen', value: l.canteenIncome, color: AppColors.green),
                          PieSlice(label: 'Membership', value: l.membershipIncome, color: AppColors.amber),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PieLegend(
                          total: l.totalIncome,
                          slices: [
                            PieSlice(label: 'Gaming', value: l.gamingIncome, color: AppColors.primary),
                            PieSlice(label: 'Canteen', value: l.canteenIncome, color: AppColors.green),
                            PieSlice(label: 'Membership', value: l.membershipIncome, color: AppColors.amber),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ── Partner withdrawals chart ────────────────────────────────
          const _SectionLabel(label: 'PARTNER BALANCES'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
            child: MiniBarChart(
              items: l.partners
                  .map((p) => BarItem(
                      label: p.name,
                      value: p.balance,
                      color: p.isNegative ? AppColors.red : AppColors.green))
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Partner cards ─────────────────────────────────────────────
          ...l.partners.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 60 * entry.key),
                  child: _PartnerCard(
                    partner: entry.value,
                    onWithdraw: () => _withdraw(context, entry.value),
                    onRepay: () => _repay(context, entry.value),
                  ),
                ),
              )),

          const SizedBox(height: 24),

          // ── Recent transactions ─────────────────────────────────────
          if (l.recentEntries.isNotEmpty) ...[
            const _SectionLabel(label: 'RECENT ACTIVITY'),
            const SizedBox(height: 10),
            ...l.recentEntries.take(15).toList().asMap().entries.map(
                (e) => FadeSlideIn(
                      delay: Duration(milliseconds: 30 * e.key),
                      child: _EntryTile(entry: e.value),
                    )),
          ],
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String icon;
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
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
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final PartnerInfo partner;
  final VoidCallback onWithdraw;
  final VoidCallback onRepay;
  const _PartnerCard({required this.partner, required this.onWithdraw, required this.onRepay});

  @override
  Widget build(BuildContext context) {
    final color = partner.isNegative ? AppColors.red : AppColors.green;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: partner.name, color: color, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partner.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Share: ${_fmt(partner.shareBase)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt(partner.balance),
                      style: TextStyle(
                          color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                  if (partner.isNegative)
                    const Text('owes café',
                        style: TextStyle(color: AppColors.red, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Taken: ${_fmt(partner.withdrawals)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              Expanded(
                child: Text('Repaid: ${_fmt(partner.repayments)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.arrow_upward, size: 15, color: AppColors.amber),
                  label: const Text('Withdraw', style: TextStyle(color: AppColors.amber, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.amber.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRepay,
                  icon: const Icon(Icons.arrow_downward, size: 15, color: AppColors.green),
                  label: const Text('Repay', style: TextStyle(color: AppColors.green, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final LedgerEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    late final String icon;
    late final Color color;
    late final bool isOutflow; // true = money left the counter

    switch (entry.type) {
      case 'expense':
        icon = '🔌';
        color = AppColors.red;
        isOutflow = true;
        break;
      case 'withdrawal':
        icon = '📤';
        color = AppColors.amber;
        isOutflow = true;
        break;
      case 'repayment':
        icon = '📥';
        color = AppColors.green;
        isOutflow = false;
        break;
      case 'contribution':
        icon = '🤝';
        color = AppColors.cyan;
        isOutflow = false;
        break;
      default:
        icon = '•';
        color = Colors.white54;
        isOutflow = false;
    }

    final subtitleParts = <String>[];
    if (entry.partnerName != null && entry.partnerName!.isNotEmpty) {
      subtitleParts.add(entry.partnerName!);
    }
    if (entry.note != null && entry.note!.isNotEmpty) {
      subtitleParts.add(entry.note!);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.label,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  if (subtitleParts.isNotEmpty)
                    Text(subtitleParts.join(' · '),
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Text(
              '${isOutflow ? '-' : '+'}${_fmt(entry.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}