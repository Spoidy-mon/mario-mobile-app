/// All session pricing lives here — one place to change rates instead of
/// hunting through dialogs and screens.
///
/// PC: flat rate per duration.
/// Wheel: same shape as PC, priced double (one rig, premium experience).
/// PS5: PC-shaped base rate, multiplied by number of players (1–4) — a
///      solo player pays the base rate, four players pay 4x.
class SessionPricing {
  SessionPricing._();

  /// Duration options offered everywhere, in minutes.
  static const List<int> durations = [30, 60, 90, 120];

  static const Map<int, double> _pcRates = {
    30: 50,
    60: 100,
    90: 150,
    120: 200,
  };

  static const Map<int, double> _wheelRates = {
    30: 100,
    60: 200,
    90: 300,
    120: 400,
  };

  // Same numbers as PC — this is the PER-PLAYER base for PS5.
  static const Map<int, double> _ps5BaseRates = _pcRates;

  static double pcPrice(int minutes) => _pcRates[minutes] ?? 0;

  static double wheelPrice(int minutes) => _wheelRates[minutes] ?? 0;

  static double ps5Price(int minutes, int players) {
    final base = _ps5BaseRates[minutes] ?? 0;
    return base * players.clamp(1, 4);
  }

  static String durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    if (minutes % 60 == 0) return '${minutes ~/ 60} hr';
    return '${(minutes / 60).toStringAsFixed(1)} hr';
  }
}