import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';

/// Prompts for a password and returns true only if it matches
/// [expectedPassword]. If [expectedPassword] is empty (not yet configured),
/// the action is allowed through without prompting at all — nobody gets
/// locked out of a feature they never set a password for.
Future<bool> requirePassword(
  BuildContext context, {
  required String title,
  required String expectedPassword,
  String subtitle = 'Enter password to continue',
}) async {
  if (expectedPassword.isEmpty) return true;

  final ctrl = TextEditingController();
  bool obscure = true;
  String? error;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                obscureText: obscure,
                keyboardType: TextInputType.visiblePassword,
                style: const TextStyle(color: Colors.white),
                decoration: appInputDecoration('Password').copyWith(
                  errorText: error,
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white38, size: 18),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
                onSubmitted: (_) {
                  if (ctrl.text == expectedPassword) {
                    Navigator.pop(ctx, true);
                  } else {
                    setState(() => error = 'Incorrect password');
                  }
                },
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
                if (ctrl.text == expectedPassword) {
                  Navigator.pop(ctx, true);
                } else {
                  setState(() => error = 'Incorrect password');
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        );
      });
    },
  );

  return result == true;
}