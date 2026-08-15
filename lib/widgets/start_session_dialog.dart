import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../services/firebase_service.dart';
import '../services/session_pricing.dart';
import '../services/report_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_snackbar.dart';

enum SessionDeviceType { pc, wheel, ps5 }

/// Opens the "Start Session" flow for a PC, the Wheel, or a PS5 slot.
/// Collects customer name (+ player count for PS5), lets staff pick a
/// duration, shows the live calculated price, and on confirm writes the
/// session straight to the same Firebase node the desktop client reads —
/// so the PC/PS5 picks it up immediately, no separate sync step. Also
/// pushes the session amount onto the Dues screen automatically, and
/// checks the typed name against enrolled members so a member's session
/// is recognised and tagged without any extra step.
Future<void> showStartSessionDialog(
  BuildContext context, {
  required String title,
  required String firebaseNode, // e.g. 'pcs/3', 'wheel_sessions/w1', 'ps5_sessions/2'
  required String deviceName, // friendly label, e.g. 'PC-3', 'Wheel', 'PS5 #2'
  required SessionDeviceType deviceType,
}) async {
  final nameCtrl = TextEditingController();
  int minutes = 30;
  int players = 1;

  final members = Provider.of<DashboardProvider>(context, listen: false).members;

  MemberInfo? matchMember(String typed) {
    final t = typed.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final m in members) {
      if (m.name.trim().toLowerCase() == t && m.isActive) return m;
    }
    return null;
  }

  // Partial-match suggestions — up to 4, active members only, so there's
  // always something tappable while typing instead of requiring the exact
  // full name before any recognition happens.
  List<MemberInfo> suggestionsFor(String typed) {
    final t = typed.trim().toLowerCase();
    if (t.isEmpty) return const [];
    final matches = members
        .where((m) => m.isActive && m.name.toLowerCase().contains(t))
        .toList();
    // Exact match already shown as the confirmed badge — no need to also
    // list it as a tappable suggestion.
    matches.removeWhere((m) => m.name.trim().toLowerCase() == t);
    return matches.take(4).toList();
  }

  double currentPrice() {
    switch (deviceType) {
      case SessionDeviceType.pc:
        return SessionPricing.pcPrice(minutes);
      case SessionDeviceType.wheel:
        return SessionPricing.wheelPrice(minutes);
      case SessionDeviceType.ps5:
        return SessionPricing.ps5Price(minutes, players);
    }
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final price = currentPrice();
        final member = matchMember(nameCtrl.text);

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
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: appInputDecoration('Customer name'),
                  onChanged: (_) => setState(() {}),
                ),
                if (member == null && suggestionsFor(nameCtrl.text).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: suggestionsFor(nameCtrl.text).map((m) {
                      return GestureDetector(
                        onTap: () => setState(() {
                          nameCtrl.text = m.name;
                          nameCtrl.selection = TextSelection.fromPosition(
                              TextPosition(offset: nameCtrl.text.length));
                        }),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.cardRaised,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.purple.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.card_membership_rounded,
                                  size: 12, color: AppColors.purple),
                              const SizedBox(width: 5),
                              Text(m.name,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (member != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 15, color: AppColors.purple),
                      const SizedBox(width: 6),
                      Text(
                        'Recognized member · ${member.plan} plan',
                        style: const TextStyle(
                            color: AppColors.purple,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Text(
                    'Already linked to this session — nothing to tap here.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
                  ),
                ],
                const SizedBox(height: 18),
                const Text('Duration',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SessionPricing.durations.map((d) {
                    final selected = d == minutes;
                    return GestureDetector(
                      onTap: () => setState(() => minutes = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.cardRaised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(
                          SessionPricing.durationLabel(d),
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (deviceType == SessionDeviceType.ps5) ...[
                  const SizedBox(height: 18),
                  const Text('Players',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StepButton(
                        icon: Icons.remove,
                        onTap: players > 1 ? () => setState(() => players--) : null,
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '$players',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StepButton(
                        icon: Icons.add,
                        onTap: players < 4 ? () => setState(() => players++) : null,
                      ),
                      const SizedBox(width: 10),
                      Text('max 4',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: member != null
                        ? AppColors.purple.withOpacity(0.12)
                        : AppColors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(member != null ? 'Amount' : 'Amount',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      member != null
                          ? Row(
                              children: [
                                Text(
                                  '₹${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14,
                                      decoration: TextDecoration.lineThrough),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'FREE',
                                  style: TextStyle(
                                      color: AppColors.purple,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            )
                          : Text(
                              '₹${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  member != null
                      ? 'Covered by their membership — logged on Dues as ₹0, not billed.'
                      : 'This goes straight onto the Dues screen for $deviceName.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Start Session'),
            ),
          ],
        );
      });
    },
  );

  if (confirmed != true) return;

  final matchedMember = matchMember(nameCtrl.text);

  try {
    await FirebaseService.startSession(
      node: firebaseNode,
      deviceName: deviceName,
      customerName: nameCtrl.text.trim(),
      minutes: minutes,
      amount: currentPrice(),
      dueAmount: matchedMember != null ? 0 : currentPrice(),
      note: matchedMember != null
          ? 'Membership session used ($minutes min)'
          : null,
      players: deviceType == SessionDeviceType.ps5 ? players : 1,
      isMember: matchedMember != null,
      memberPlan: matchedMember?.plan ?? '',
    );
    if (context.mounted) {
      showAppSnackbar(
        context,
        matchedMember != null
            ? 'Membership session started for ${nameCtrl.text.trim()}'
            : 'Session started for ${nameCtrl.text.trim()}',
      );
    }
  } catch (e) {
    if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.cardRaised,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: enabled ? Colors.white70 : AppColors.textMuted),
      ),
    );
  }
}