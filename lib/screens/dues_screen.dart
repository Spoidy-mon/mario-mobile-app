import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_provider.dart';
import '../services/dashboard_model.dart';
import '../services/firebase_service.dart';
import '../widgets/fade_slide_in.dart';
import '../theme/app_colors.dart';
import '../theme/app_snackbar.dart';
import '../widgets/password_gate_dialog.dart';


class DuesScreen extends StatelessWidget {
  const DuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final stats = prov.stats;
    final dues = stats.dues;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Pending Dues',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '₹${stats.pendingDuesTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: dues.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✅', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('No pending dues!',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: dues.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => FadeSlideIn(
                delay: Duration(milliseconds: 40 * i),
                child: _DueTile(due: dues[i], cafeName: stats.cafeeName, expensePwd: prov.expensePassword),
              ),
            ),
    );
  }
}

class _DueTile extends StatelessWidget {
  final DueItem due;
  final String cafeName;
  final String expensePwd;
  const _DueTile({required this.due, required this.cafeName, required this.expensePwd});

  Future<void> _deleteDue(BuildContext context, String expensePwd) async {
    final unlocked = await requirePassword(
      context,
      title: 'Delete Due',
      expectedPassword: expensePwd,
      subtitle: 'Enter the Mario Gaming expense password to permanently delete this due.',
    );
    if (!unlocked || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete permanently?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This erases ${due.customerName.isNotEmpty ? due.customerName : 'this'}\'s '
          'due of ₹${due.amount.toStringAsFixed(0)} with no record kept. '
          'Use "Mark Paid" instead if the money was actually collected.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseService.deleteDue(due.key);
      if (context.mounted) showAppSnackbar(context, 'Due deleted');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _markPaid(BuildContext context) async {
    try {
      await FirebaseService.markDuePaid(due.key, {
        'customer_name': due.customerName,
        'pc_name': due.pcName,
        'amount': due.amount,
        'created_at': due.createdAt,
      });
      if (context.mounted) showAppSnackbar(context, 'Marked as paid');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _copyReminder(BuildContext context) async {
    final name = due.customerName.isNotEmpty ? due.customerName : 'there';
    final msg =
        'Hi $name, this is a friendly reminder from $cafeName — you have a pending due of '
        '₹${due.amount.toStringAsFixed(0)} for ${due.pcName}. Please clear it whenever you\'re next in. Thanks!';
    await Clipboard.setData(ClipboardData(text: msg));
    if (context.mounted) {
      showAppSnackbar(context, 'Reminder message copied — paste it in WhatsApp/SMS');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = DateTime.fromMillisecondsSinceEpoch(due.createdAt);
    final timeStr = DateFormat('h:mm a').format(ts);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    due.customerName.isNotEmpty
                        ? due.customerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      due.customerName.isNotEmpty ? due.customerName : 'Unknown',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${due.pcName}  ·  $timeStr',
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${due.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyReminder(context),
                  icon: const Icon(Icons.message_rounded, size: 15, color: AppColors.amber),
                  label: const Text('Copy Reminder',
                      style: TextStyle(color: AppColors.amber, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.amber.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markPaid(context),
                  icon: const Icon(Icons.check_circle_outline, size: 15, color: AppColors.green),
                  label: const Text('Mark Paid', style: TextStyle(color: AppColors.green, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.green.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Permanent delete — password-gated, for correcting mistaken
              // entries. "Mark Paid" is the right action for real payments.
              OutlinedButton(
                onPressed: () => _deleteDue(context, expensePwd),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.red.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  minimumSize: Size.zero,
                ),
                child: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}