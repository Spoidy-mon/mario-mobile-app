import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_snackbar.dart';

/// Confirms and ends an active session — frees the device back to idle.
/// The amount already charged to the customer's due when the session
/// started is untouched; this only stops the timer and clears the device.
Future<void> showEndSessionDialog(
  BuildContext context, {
  required String firebaseNode,
  required String deviceName,
  required String customerName,
  required String timeLeft,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('End Session · $deviceName',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (customerName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(customerName,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          if (timeLeft.isNotEmpty && timeLeft != '00:00')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 15, color: AppColors.amber),
                  const SizedBox(width: 6),
                  Text('$timeLeft still on the clock',
                      style: const TextStyle(color: AppColors.amber, fontSize: 13)),
                ],
              ),
            ),
          const Text(
            'This frees the device back to idle. The amount already on '
            'their tab from starting this session is not changed.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('End Session'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await FirebaseService.endSession(firebaseNode);
    if (context.mounted) showAppSnackbar(context, '$deviceName freed up');
  } catch (e) {
    if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
  }
}