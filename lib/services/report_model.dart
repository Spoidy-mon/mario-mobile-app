/// Models for Canteen Stock, Membership roster, and date-range Reports.
///
/// FIREBASE SCHEMA (new nodes this feature reads/writes):
///   canteen_stock/{id}   { name, quantity, unit, low_threshold, price }
///   memberships/{id}     { name, phone, plan, joined_at, expires_at }
///
/// If your React admin app already stores these under different node
/// names, update the stream paths in FirebaseService to match — everything
/// else adapts automatically since it all reads from these two lists.
library;

class StockItem {
  final String key;
  final String name;
  final double quantity;
  final String unit;
  final double lowThreshold;
  final double price;
  final String sourceNode; // which Firebase root node this came from
  final String quantityField; // which field on that node holds the quantity
  final String emoji;
  final String category;

  const StockItem({
    required this.key,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.lowThreshold,
    required this.price,
    this.sourceNode = 'canteen_stock',
    this.quantityField = 'quantity',
    this.emoji = '',
    this.category = '',
  });

  bool get isOut => quantity <= 0;
  bool get isLow => !isOut && quantity <= lowThreshold;
}

class MemberInfo {
  final String key;
  final String name;
  final String phone;
  final String plan;
  final int joinedAt;
  final int expiresAt; // 0 = no expiry

  const MemberInfo({
    required this.key,
    required this.name,
    required this.phone,
    required this.plan,
    required this.joinedAt,
    required this.expiresAt,
  });

  bool get isActive =>
      expiresAt == 0 || DateTime.now().millisecondsSinceEpoch < expiresAt;

  int get daysLeft {
    if (expiresAt == 0) return 9999;
    final diff = expiresAt - DateTime.now().millisecondsSinceEpoch;
    return (diff / (1000 * 60 * 60 * 24)).ceil();
  }
}

/// Revenue snapshot for an arbitrary [start, end) date range, computed
/// on-demand from whatever data is already cached in DashboardProvider.
class ReportStats {
  final DateTime start;
  final DateTime end;
  final double pcRevenue;
  final double ps5Revenue;
  final double canteenRevenue;
  final double membershipRevenue;
  final double cashTotal;
  final double upiTotal;
  final int gamingTransactions;
  final int canteenTransactions;
  final int membershipTransactions;

  const ReportStats({
    required this.start,
    required this.end,
    this.pcRevenue = 0,
    this.ps5Revenue = 0,
    this.canteenRevenue = 0,
    this.membershipRevenue = 0,
    this.cashTotal = 0,
    this.upiTotal = 0,
    this.gamingTransactions = 0,
    this.canteenTransactions = 0,
    this.membershipTransactions = 0,
  });

  double get gamingRevenue => pcRevenue + ps5Revenue;
  double get totalRevenue => gamingRevenue + canteenRevenue + membershipRevenue;
}