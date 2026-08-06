import 'package:flutter/material.dart';

/// Single shared palette for the whole app.
///
/// Colours here are SEMANTIC, not decorative — each one means something
/// specific, so a glance at the screen reads as information rather than
/// styling. Money coming in is always [green]; money leaving is always
/// [red]; things needing attention are [amber]. Never pick a colour for
/// looks alone — pick the one whose meaning fits.
class AppColors {
  AppColors._();

  // ── Surfaces ────────────────────────────────────────────────────────
  /// Page background — near-black with a slight blue cast so the coloured
  /// data reads as luminous against it.
  static const bg = Color(0xFF0B0E14);

  /// Standard card surface, one step above the page.
  static const card = Color(0xFF151A24);

  /// Raised surface, for grouping rows inside a card.
  static const cardRaised = Color(0xFF1C2331);

  /// Hairline borders and dividers.
  static const border = Color(0xFF252D3B);

  // ── Text ────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF2F5FA);
  static const textSecondary = Color(0xFF8A94A6);
  static const textMuted = Color(0xFF5A6474);

  // ── Semantic ────────────────────────────────────────────────────────
  /// Brand / interactive. Also the gaming category.
  static const primary = Color(0xFF5B8DEF);

  /// Money in, healthy, available.
  static const green = Color(0xFF2ECC8F);

  /// Money out, overdue, out of stock.
  static const red = Color(0xFFFF5A6E);

  /// Needs attention but not yet a problem — running low, pending.
  static const amber = Color(0xFFFFB020);

  /// Canteen / food category.
  static const cyan = Color(0xFF35C4DC);

  /// Membership category.
  static const purple = Color(0xFF9B7BF5);

  // ── The one gradient ────────────────────────────────────────────────
  /// Reserved for the single hero figure — today's earnings. Using it
  /// exactly once is what makes it read as "this is the number that
  /// matters" rather than as background decoration.
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF2ECC8F), Color(0xFF1FA8C4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}