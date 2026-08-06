/// Only these statuses mean a session is actually IN PROGRESS (someone
/// playing, timer running). "online" / "available" means the PC/PS5 is
/// powered on and the client software is reporting in, but NOBODY is
/// using it — that must NOT count as an active session. This was the bug:
/// a too-broad blacklist previously treated "online" as active.
const _activeStatuses = {
  'active',
  'running',
  'in_use',
  'in-use',
  'busy',
  'occupied',
  'in_session',
  'playing',
};

bool isStatusActive(String status) =>
    _activeStatuses.contains(status.toLowerCase().trim());

class DashboardStats {
  final int activePcSessions;
  final int activePs5Sessions;
  final double todayGamingRevenue;
  final double todayCanteenRevenue;
  final double todayTotalRevenue;
  final double todayCash;
  final double todayUpi;
  final double pendingDuesTotal;
  final int pendingDuesCount;
  final double electricityCost30d;
  final double electricityUnits30d;
  final double latestMetreReading;
  final String cafeeName;
  final double electricityRate;
  final List<PcStatus> pcs;
  final List<Ps5Status> ps5s;
  final List<DueItem> dues;

  const DashboardStats({
    this.activePcSessions = 0,
    this.activePs5Sessions = 0,
    this.todayGamingRevenue = 0,
    this.todayCanteenRevenue = 0,
    this.todayTotalRevenue = 0,
    this.todayCash = 0,
    this.todayUpi = 0,
    this.pendingDuesTotal = 0,
    this.pendingDuesCount = 0,
    this.electricityCost30d = 0,
    this.electricityUnits30d = 0,
    this.latestMetreReading = 0,
    this.cafeeName = 'Mario Gaming Café',
    this.electricityRate = 8,
    this.pcs = const [],
    this.ps5s = const [],
    this.dues = const [],
  });

  int get totalActive => activePcSessions + activePs5Sessions;
}

class PcStatus {
  final int id;
  final String name;
  final String status; // offline | online | active
  final bool isPaused;
  final int timeRemaining; // seconds
  final String customerName;
  final String paymentStatus; // pending | partial | paid

  const PcStatus({
    required this.id,
    required this.name,
    required this.status,
    this.isPaused = false,
    this.timeRemaining = 0,
    this.customerName = '',
    this.paymentStatus = '',
  });

  /// A status word alone isn't enough proof — Firebase can be left with a
  /// stale "active" flag from a session that ended without properly
  /// resetting. Requiring time_remaining > 0 too means a session only
  /// counts as live if there's an actual running countdown.
  /// A session counts as live if the status looks active AND there's real
  /// evidence of an ongoing session — either time still on the clock, or a
  /// customer assigned to it. Requiring time alone missed paused/unlimited
  /// sessions; requiring status alone counted stale leftover flags.
  bool get isActive =>
      isStatusActive(status) && (timeRemaining > 0 || customerName.isNotEmpty);
  bool get isLow => isActive && timeRemaining <= 300 && timeRemaining > 0 && !isPaused;
  String get timeStr {
    if (timeRemaining <= 0) return '00:00';
    final h = timeRemaining ~/ 3600;
    final m = (timeRemaining % 3600) ~/ 60;
    final s = timeRemaining % 60;
    if (h > 0) return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }
}

class Ps5Status {
  final int slot;
  final String status;
  final bool isPaused;
  final int timeRemaining;
  final String customerName;
  final String paymentStatus;

  const Ps5Status({
    required this.slot,
    required this.status,
    this.isPaused = false,
    this.timeRemaining = 0,
    this.customerName = '',
    this.paymentStatus = '',
  });

  bool get isActive =>
      isStatusActive(status) && (timeRemaining > 0 || customerName.isNotEmpty);
  String get timeStr {
    if (timeRemaining <= 0) return '00:00';
    final h = timeRemaining ~/ 3600;
    final m = (timeRemaining % 3600) ~/ 60;
    final s = timeRemaining % 60;
    if (h > 0) return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }
}

class DueItem {
  final String key;
  final String customerName;
  final String pcName;
  final double amount;
  final bool paid;
  final int createdAt;

  const DueItem({
    required this.key,
    required this.customerName,
    required this.pcName,
    required this.amount,
    required this.paid,
    required this.createdAt,
  });
}