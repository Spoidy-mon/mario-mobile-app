/// Data models for the Partner Ledger feature.
///
/// FIREBASE SCHEMA (new nodes added by this feature):
///   mario_expenses/{id}        { category, amount, note, created_at }
///   partner_withdrawals/{id}   { partner_id, partner_name, amount, note, created_at }
///   partner_repayments/{id}    { partner_id, partner_name, amount, note, created_at }
///   business_contributions/{id}{ partner_id, partner_name, amount, note, created_at }
///   membership_payments/{id}   { amount, payment_mode ('cash'|'upi'), customer_name, paid_at }
///   settings/partner1Name, partner2Name, partner3Name   (optional, default "Partner 1/2/3")
///
/// If your existing Firebase project already stores membership income under a
/// different node name, update FirebaseService.membershipStream() to match it.

class PartnerInfo {
  final String id;
  final String name;
  final double shareBase; // this partner's equal 1/3 share of distributable profit
  final double withdrawals; // total ever withdrawn by this partner
  final double repayments; // total ever repaid by this partner against their own balance

  const PartnerInfo({
    required this.id,
    required this.name,
    required this.shareBase,
    required this.withdrawals,
    required this.repayments,
  });

  /// Current balance = fair share - what they've taken out + what they've paid back.
  /// Goes negative the moment withdrawals exceed (share + repayments).
  double get balance => shareBase - withdrawals + repayments;
  bool get isNegative => balance < -0.009;
}

class LedgerEntry {
  final String key;
  final String type; // expense | withdrawal | repayment | contribution
  final String label;
  final double amount;
  final int createdAt;
  final String? partnerName;
  final String? note;

  const LedgerEntry({
    required this.key,
    required this.type,
    required this.label,
    required this.amount,
    required this.createdAt,
    this.partnerName,
    this.note,
  });
}

class LedgerStats {
  /// Actual physical cash that should be sitting in the counter right now.
  final double counterCash;

  /// All-time cash revenue (gaming + canteen + membership), cash portion only.
  final double totalCashRevenue;

  /// All-time Mario Gaming operational expenses (electricity, rent, etc.)
  final double totalExpenses;

  /// All-time money partners have put in to cover a Mario Gaming deficit.
  final double totalContributions;

  /// totalCashRevenue - totalExpenses + totalContributions.
  /// Negative = Mario Gaming (the business) is running a deficit.
  final double marioGamingBalance;

  /// All-time income (cash + UPI) per source, for the breakdown chart.
  final double gamingIncome;
  final double canteenIncome;
  final double membershipIncome;

  final List<PartnerInfo> partners;
  final List<LedgerEntry> recentEntries;

  const LedgerStats({
    this.counterCash = 0,
    this.totalCashRevenue = 0,
    this.totalExpenses = 0,
    this.totalContributions = 0,
    this.marioGamingBalance = 0,
    this.gamingIncome = 0,
    this.canteenIncome = 0,
    this.membershipIncome = 0,
    this.partners = const [],
    this.recentEntries = const [],
  });

  double get totalIncome => gamingIncome + canteenIncome + membershipIncome;
  bool get isMarioNegative => marioGamingBalance < -0.009;
}