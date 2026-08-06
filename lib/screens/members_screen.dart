import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../services/firebase_service.dart';
import '../services/report_model.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/initials_avatar.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_snackbar.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  InputDecoration _dec(String label) => appInputDecoration(label, accent: AppColors.primary);

  Future<void> _addMember(BuildContext context, String sourceNode) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final planCtrl = TextEditingController(text: 'Standard');
    DateTime? expiryDate;
    bool noExpiry = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Member',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Member name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Phone (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: planCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Plan (e.g. Monthly, Gold)'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Checkbox(
                      value: noExpiry,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => noExpiry = v ?? false),
                    ),
                    const Text('No expiry', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                if (!noExpiry)
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: now,
                        lastDate: DateTime(now.year + 5),
                        initialDate: expiryDate ?? now.add(const Duration(days: 30)),
                        builder: (c, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                                primary: AppColors.primary, surface: AppColors.card, onSurface: Colors.white),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => expiryDate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Text(
                            expiryDate == null
                                ? 'Select expiry date'
                                : '${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                if (!noExpiry && expiryDate == null) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Add Member'),
            ),
          ],
        );
      }),
    );

    if (result != true) return;
    try {
      await FirebaseService.addMember(
        node: sourceNode,
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        plan: planCtrl.text.trim().isEmpty ? 'Standard' : planCtrl.text.trim(),
        expiresAt: noExpiry ? 0 : expiryDate!.millisecondsSinceEpoch,
      );
      if (context.mounted) showAppSnackbar(context, 'Member added');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final members = prov.members;
    final active = members.where((m) => m.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Members',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$active active',
                  style: const TextStyle(
                      color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMember(context, prov.membersSourceNode),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Member'),
      ),
      body: members.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎟', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 12),
                  const Text('No members enrolled yet',
                      style: TextStyle(color: Colors.white54, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Tap "Add Member" below to enroll your first member.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => FadeSlideIn(
                delay: Duration(milliseconds: 35 * i),
                child: _MemberTile(member: members[i], sourceNode: prov.membersSourceNode),
              ),
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final MemberInfo member;
  final String sourceNode;
  const _MemberTile({required this.member, required this.sourceNode});

  Future<void> _confirmDeactivate(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate member?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This will immediately expire ${member.name}\'s membership.',
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
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseService.deactivateMember(sourceNode, member.key);
      if (context.mounted) {
        showAppSnackbar(context, '${member.name} deactivated', error: true);
      }
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = member.isActive ? AppColors.green : AppColors.red;
    final expiryText = member.expiresAt == 0
        ? 'No expiry'
        : (member.isActive
            ? '${member.daysLeft} day${member.daysLeft == 1 ? '' : 's'} left'
            : 'Expired');

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
          Row(
            children: [
              InitialsAvatar(name: member.name, color: AppColors.primary, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                        '${member.plan}${member.phone.isNotEmpty ? ' · ${member.phone}' : ''}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(expiryText,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (member.isActive) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDeactivate(context),
                icon: const Icon(Icons.block, size: 14, color: AppColors.amber),
                label: const Text('Deactivate', style: TextStyle(color: AppColors.amber, fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.amber.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}