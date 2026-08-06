import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Consistent dialog TextField styling — used to be redefined as a private
/// `_dec`/`_inputDecoration` function in every screen with a form dialog.
InputDecoration appInputDecoration(String label, {Color accent = AppColors.primary}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white54),
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: accent),
    ),
  );
}