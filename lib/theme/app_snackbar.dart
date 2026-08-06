import 'package:flutter/material.dart';
import 'app_colors.dart';

/// One shared success/error snackbar — this exact try/catch/SnackBar
/// pattern used to be copy-pasted in every screen that writes to
/// Firebase (Stock, Members, Dues, Ledger).
void showAppSnackbar(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.red : AppColors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}