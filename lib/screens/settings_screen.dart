import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/password_gate_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_snackbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _renamePartner(
      BuildContext context, String partnerId, String currentName, String currentPwd) async {
    // Renaming is gated by that partner's own password, if they've set one.
    if (currentPwd.isNotEmpty) {
      final unlocked = await requirePassword(
        context,
        title: currentName,
        expectedPassword: currentPwd,
        subtitle: 'Enter $currentName\'s password to rename.',
      );
      if (!unlocked) return;
    }
    if (!context.mounted) return;

    final ctrl = TextEditingController(text: currentName);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Partner',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: appInputDecoration('Partner name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;
    try {
      await FirebaseService.setPartnerName(partnerId, ctrl.text.trim());
      if (context.mounted) showAppSnackbar(context, 'Renamed to ${ctrl.text.trim()}');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _changePartnerPassword(
      BuildContext context, String partnerId, String partnerName, String currentPwd) async {
    // If a password is already set, must unlock with it first.
    if (currentPwd.isNotEmpty) {
      final unlocked = await requirePassword(
        context,
        title: partnerName,
        expectedPassword: currentPwd,
        subtitle: 'Enter the current password to change it.',
      );
      if (!unlocked) return;
    }
    if (!context.mounted) return;

    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Set $partnerName\'s Password',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              style: const TextStyle(color: Colors.white),
              decoration: appInputDecoration('New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              style: const TextStyle(color: Colors.white),
              decoration: appInputDecoration('Confirm password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (ctrl.text.isEmpty || ctrl.text != confirmCtrl.text) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (ctrl.text != confirmCtrl.text) {
      if (context.mounted) showAppSnackbar(context, 'Passwords did not match', error: true);
      return;
    }
    try {
      await FirebaseService.setPartnerPassword(partnerId, ctrl.text);
      if (context.mounted) showAppSnackbar(context, '$partnerName\'s password updated');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _confirmResetApp(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset App?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'This restarts the app fresh — reloading everything live from Firebase. '
          'Your Firebase data (sessions, dues, stock, members, ledger history) is '
          'NOT deleted; this only clears anything cached on this phone.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    // Pops back to the very first route (the splash screen), which
    // re-runs Firebase init and rebuilds the whole provider fresh.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final pwds = prov.partnerPasswords;
    final names = prov.partnerNames;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel(label: 'PARTNERS'),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Rename a partner, or set the password they need to Withdraw, '
              'Repay, or contribute funds in the Partner Ledger.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          ...['p1', 'p2', 'p3'].map((id) {
            final label = names[id] ?? 'Partner';
            final isSet = (pwds[id] ?? '').isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_outline_rounded,
                              size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(isSet ? 'Password set' : 'No password set',
                                  style: TextStyle(
                                      color: isSet ? AppColors.green : AppColors.amber,
                                      fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _renamePartner(context, id, label, pwds[id] ?? ''),
                            icon: const Icon(Icons.edit_outlined,
                                size: 14, color: AppColors.primary),
                            label: const Text('Rename',
                                style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _changePartnerPassword(
                                context, id, label, pwds[id] ?? ''),
                            icon: const Icon(Icons.lock_outline_rounded,
                                size: 14, color: AppColors.amber),
                            label: const Text('Password',
                                style: TextStyle(color: AppColors.amber, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.amber.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          const _SectionLabel(label: 'MARIO GAMING EXPENSES'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.lock_person_rounded,
            title: 'Expense Password',
            subtitle:
                'Fixed by the developer — required to add electricity/rent/etc. expenses',
            subtitleColor: Colors.white38,
            trailing: const Text('Locked',
                style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w600, fontSize: 12.5)),
            onTap: null,
          ),

          const SizedBox(height: 20),
          const _SectionLabel(label: 'APP'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.restart_alt_rounded,
            title: 'Reset App',
            subtitle: 'Clears local cache and reloads fresh from Firebase',
            subtitleColor: Colors.white38,
            trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            onTap: () => _confirmResetApp(context),
          ),

          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Everything here syncs live via Firebase — a password changed on '
              'one phone applies instantly everywhere else the app is open.',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: subtitleColor, fontSize: 11.5)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}