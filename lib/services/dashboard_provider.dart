import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';
import 'dashboard_model.dart';
import 'ledger_model.dart';
import 'report_model.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardStats _stats = const DashboardStats();
  LedgerStats _ledger = const LedgerStats();
  bool _loading = true;
  String? _error;

  DashboardStats get stats => _stats;
  LedgerStats get ledger => _ledger;
  bool get loading => _loading;
  String? get error => _error;

  List<StockItem> _stock = [];
  List<MemberInfo> _members = [];
  String _membersSourceNode = 'memberships';
  String _stockSourceNode = 'canteen_stock';
  List<StockItem> get stock => _stock;
  List<MemberInfo> get members => _members;
  String get membersSourceNode => _membersSourceNode;
  String get stockSourceNode => _stockSourceNode;

  /// If the stock builder threw, the message lands here and is surfaced in
  /// the Stock screen's empty state — so a parsing failure shows up as a
  /// readable reason instead of a silently blank list.
  String? _stockError;
  String? get stockError => _stockError;

  /// Raw child-count of every stock node candidate, for on-screen debugging.
  /// If the real node shows a count here but parsed items is 0, the problem
  /// is field parsing; if every count is 0, the streams aren't delivering.
  String get stockCandidateCounts =>
      'canteen_items:${_canteenItemsAltRaw.length}  '
      'canteen_stock:${_stockRaw.length}\n'
      'menu_items:${_menuItemsAltRaw.length}  '
      'menu:${_menuAltRaw.length}  '
      'products:${_productsAltRaw.length}\n'
      'items:${_itemsAltRaw.length}  '
      'stock:${_stockAltRaw.length}  '
      'inventory:${_inventoryAltRaw.length}';

  /// Per-partner passwords (p1/p2/p3). Empty string means "not yet set" —
  /// in that case the action is NOT password-gated, so existing users
  /// aren't locked out until they deliberately set one via Settings.
  Map<String, String> get partnerPasswords {
    final raw = _settingsRaw['partnerPasswords'];
    if (raw is Map) {
      return {
        'p1': (raw['p1'] ?? '').toString(),
        'p2': (raw['p2'] ?? '').toString(),
        'p3': (raw['p3'] ?? '').toString(),
      };
    }
    return const {'p1': '', 'p2': '', 'p3': ''};
  }

  /// The Mario Gaming expense password is fixed at "2811" — hardcoded
  /// here rather than read from Firebase, so it cannot be changed by
  /// anyone editing settings in the app, or by editing the database
  /// directly. Changing it requires editing this line in the app's source
  /// and shipping a new build.
  String get expensePassword => '2811';

  /// Editable partner display names, read live from settings so a rename
  /// on one device shows up everywhere. Falls back to generic labels.
  Map<String, String> get partnerNames => {
        'p1': (_settingsRaw['partner1Name'] ?? 'Partner 1').toString(),
        'p2': (_settingsRaw['partner2Name'] ?? 'Partner 2').toString(),
        'p3': (_settingsRaw['partner3Name'] ?? 'Partner 3').toString(),
      };

  // Raw caches — rebuilt whenever any stream fires
  Map<dynamic, dynamic> _pcsRaw = {};
  Map<dynamic, dynamic> _ps5Raw = {};
  Map<dynamic, dynamic> _duesRaw = {};
  Map<dynamic, dynamic> _salesRaw = {};
  Map<dynamic, dynamic> _paymentsRaw = {};
  List<dynamic> _metreRaw = [];
  Map<dynamic, dynamic> _settingsRaw = {};
  Map<dynamic, dynamic> _wheelRaw = {};

  // Raw caches — Partner Ledger
  Map<dynamic, dynamic> _membershipRaw = {};
  Map<dynamic, dynamic> _expensesRaw = {};
  Map<dynamic, dynamic> _withdrawalsRaw = {};
  Map<dynamic, dynamic> _repaymentsRaw = {};
  Map<dynamic, dynamic> _contributionsRaw = {};

  // Raw caches — Stock / Members (multiple name candidates — see below)
  Map<dynamic, dynamic> _stockRaw = {};
  Map<dynamic, dynamic> _stockAltRaw = {};
  Map<dynamic, dynamic> _inventoryAltRaw = {};
  Map<dynamic, dynamic> _productsAltRaw = {};
  Map<dynamic, dynamic> _canteenItemsAltRaw = {};
  Map<dynamic, dynamic> _menuItemsAltRaw = {};
  Map<dynamic, dynamic> _menuAltRaw = {};
  Map<dynamic, dynamic> _itemsAltRaw = {};
  Map<dynamic, dynamic> _membersRaw = {};
  Map<dynamic, dynamic> _membersAltRaw = {};
  Map<dynamic, dynamic> _membershipAltRaw = {};

  final List<StreamSubscription> _subs = [];

  void init() {
    _subs.add(FirebaseService.pcsStream().listen(_onPcs, onError: _onErr));
    _subs.add(FirebaseService.ps5Stream().listen(_onPs5, onError: _onErr));
    _subs.add(FirebaseService.pendingDuesStream().listen(_onDues, onError: _onErr));
    _subs.add(FirebaseService.salesStream().listen(_onSales, onError: _onErr));
    _subs.add(FirebaseService.paymentsStream().listen(_onPayments, onError: _onErr));
    _subs.add(FirebaseService.metreStream().listen(_onMetre, onError: _onErr));
    _subs.add(FirebaseService.settingsStream().listen(_onSettings, onError: _onErr));
    _subs.add(FirebaseService.wheelStream().listen(_onWheel, onError: _onErr));

    // Partner Ledger streams
    _subs.add(FirebaseService.membershipStream().listen(_onMembership, onError: _onErr));
    _subs.add(FirebaseService.marioExpensesStream().listen(_onExpenses, onError: _onErr));
    _subs.add(FirebaseService.partnerWithdrawalsStream().listen(_onWithdrawals, onError: _onErr));
    _subs.add(FirebaseService.partnerRepaymentsStream().listen(_onRepayments, onError: _onErr));
    _subs.add(FirebaseService.businessContributionsStream().listen(_onContributions, onError: _onErr));

    // Stock / Members streams (multiple name candidates)
    _subs.add(FirebaseService.canteenStockStream().listen(_onStock, onError: _onErr));
    _subs.add(FirebaseService.stockAltStream().listen(_onStockAlt, onError: _onErr));
    _subs.add(FirebaseService.inventoryAltStream().listen(_onInventoryAlt, onError: _onErr));
    _subs.add(FirebaseService.productsAltStream().listen(_onProductsAlt, onError: _onErr));
    _subs.add(FirebaseService.canteenItemsAltStream().listen(_onCanteenItemsAlt, onError: _onErr));
    _subs.add(FirebaseService.menuItemsAltStream().listen(_onMenuItemsAlt, onError: _onErr));
    _subs.add(FirebaseService.menuAltStream().listen(_onMenuAlt, onError: _onErr));
    _subs.add(FirebaseService.itemsAltStream().listen(_onItemsAlt, onError: _onErr));
    _subs.add(FirebaseService.membershipsStream().listen(_onMembers, onError: _onErr));
    _subs.add(FirebaseService.membersAltStream().listen(_onMembersAlt, onError: _onErr));
    _subs.add(FirebaseService.membershipAltStream().listen(_onMembershipAlt, onError: _onErr));
  }

  void _onErr(dynamic e) {
    _error = e.toString();
    _loading = false;
    notifyListeners();
  }

  /// Firebase Realtime Database silently turns a node into a JSON array
  /// (List) instead of a Map whenever its keys happen to be sequential
  /// integers starting at 0. Every handler below must tolerate BOTH shapes
  /// or the app crashes with "List<Object?> is not a subtype of Map" the
  /// instant that node's data looks array-like. This normalizes either
  /// shape into a Map<dynamic,dynamic> keyed by index/string so the rest of
  /// the code (which expects entries with .key/.value) keeps working.
  /// Firebase nodes aren't guaranteed to hold Maps — a child can be a bare
  /// int/String/bool (e.g. a node storing `{ balance: 5000 }`, or a scalar
  /// settings value). A raw `as Map?` cast throws on those and, because
  /// every stream calls _rebuild(), a single bad value would crash the
  /// whole rebuild on EVERY event — silently leaving stock, members and
  /// everything else empty. This returns null instead so the entry is
  /// simply skipped.
  static Map? _asMap(dynamic v) => v is Map ? v : null;

  static Map<dynamic, dynamic> _normalizeToMap(dynamic v) {
    if (v == null) return {};
    if (v is Map) return v;
    if (v is List) {
      final map = <dynamic, dynamic>{};
      for (int i = 0; i < v.length; i++) {
        if (v[i] != null) map[i.toString()] = v[i];
      }
      return map;
    }
    return {};
  }

  void _onPcs(DatabaseEvent e) {
    _pcsRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onPs5(DatabaseEvent e) {
    _ps5Raw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onDues(DatabaseEvent e) {
    _duesRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onSales(DatabaseEvent e) {
    _salesRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onPayments(DatabaseEvent e) {
    _paymentsRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onMetre(DatabaseEvent e) {
    final v = e.snapshot.value;
    if (v is List) {
      _metreRaw = v.where((x) => x != null).toList();
    } else if (v is Map) {
      _metreRaw = v.values.toList();
    } else {
      _metreRaw = [];
    }
    _rebuild();
  }

  void _onSettings(DatabaseEvent e) {
    _settingsRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onWheel(DatabaseEvent e) {
    _wheelRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onMembership(DatabaseEvent e) {
    _membershipRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onExpenses(DatabaseEvent e) {
    _expensesRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onWithdrawals(DatabaseEvent e) {
    _withdrawalsRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onRepayments(DatabaseEvent e) {
    _repaymentsRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onContributions(DatabaseEvent e) {
    _contributionsRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onStock(DatabaseEvent e) {
    _stockRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onStockAlt(DatabaseEvent e) {
    _stockAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onInventoryAlt(DatabaseEvent e) {
    _inventoryAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onProductsAlt(DatabaseEvent e) {
    _productsAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onCanteenItemsAlt(DatabaseEvent e) {
    _canteenItemsAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onMenuItemsAlt(DatabaseEvent e) {
    _menuItemsAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onMenuAlt(DatabaseEvent e) {
    _menuAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onItemsAlt(DatabaseEvent e) {
    _itemsAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onMembers(DatabaseEvent e) {
    _membersRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onMembersAlt(DatabaseEvent e) {
    _membersAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _onMembershipAlt(DatabaseEvent e) {
    _membershipAltRaw = _normalizeToMap(e.snapshot.value);
    _rebuild();
  }

  void _rebuild() {
    _loading = false;
    _error = null;

    // ── Settings ──────────────────────────────────────────────────────────
    final cafeeName = (_settingsRaw['cafeeName'] ?? 'Mario Gaming Café').toString();
    final electricityRate = double.tryParse(_settingsRaw['electricityRate']?.toString() ?? '8') ?? 8.0;

    // ── Today boundary ────────────────────────────────────────────────────
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    // ── PCs ───────────────────────────────────────────────────────────────
    final pcs = <PcStatus>[];
    for (final entry in _pcsRaw.entries) {
      final pc = _asMap(entry.value);
      if (pc == null) continue;
      final status = pc['status']?.toString() ?? 'offline';
      final isPaused = pc['is_paused'] == true;
      final timeRem = _toInt(pc['time_remaining']);
      pcs.add(PcStatus(
        id: _toInt(pc['id']),
        firebaseKey: entry.key.toString(),
        name: pc['name']?.toString() ?? 'PC-?',
        status: status,
        isPaused: isPaused,
        timeRemaining: timeRem,
        customerName: pc['customer_name']?.toString() ?? '',
        paymentStatus: pc['payment_status']?.toString() ?? '',
      ));
    }
    pcs.sort((a, b) => a.id.compareTo(b.id));
    // Count via the model's own isActive getter — one source of truth,
    // instead of duplicating the "active" condition here separately.
    final activePcs = pcs.where((p) => p.isActive).length;

    // ── PS5 ───────────────────────────────────────────────────────────────
    final ps5s = <Ps5Status>[];
    for (final entry in _ps5Raw.entries) {
      final s = _asMap(entry.value);
      if (s == null) continue;
      final status = s['status']?.toString() ?? 'offline';
      ps5s.add(Ps5Status(
        slot: _toInt(s['slot']),
        firebaseKey: entry.key.toString(),
        status: status,
        isPaused: s['is_paused'] == true,
        timeRemaining: _toInt(s['time_remaining']),
        customerName: s['customer_name']?.toString() ?? '',
        paymentStatus: s['payment_status']?.toString() ?? '',
      ));
    }
    final activePs5 = ps5s.where((p) => p.isActive).length;
    ps5s.sort((a, b) => a.slot.compareTo(b.slot));

    // ── Wheel (single device) ───────────────────────────────────────────
    PcStatus? wheel;
    if (_wheelRaw.isNotEmpty) {
      final entry = _wheelRaw.entries.first;
      final w = _asMap(entry.value);
      if (w != null) {
        wheel = PcStatus(
          id: 1,
          firebaseKey: entry.key.toString(),
          name: w['name']?.toString() ?? 'Wheel',
          status: w['status']?.toString() ?? 'offline',
          isPaused: w['is_paused'] == true,
          timeRemaining: _toInt(w['time_remaining']),
          customerName: w['customer_name']?.toString() ?? '',
          paymentStatus: w['payment_status']?.toString() ?? '',
        );
      }
    }

    // ── Today's payments (gaming) ─────────────────────────────────────────
    double gamingCash = 0, gamingUpi = 0;
    for (final p in _paymentsRaw.values) {
      final pay = _asMap(p);
      if (pay == null) continue;
      final ts = _toInt(pay['paid_at']);
      if (ts < todayStart) continue;
      gamingCash += _toDouble(pay['cash']);
      gamingUpi  += _toDouble(pay['upi']);
    }

    // ── Today's canteen sales ─────────────────────────────────────────────
    double canteenTotal = 0, canteenCash = 0, canteenUpi = 0;
    for (final s in _salesRaw.values) {
      final sale = _asMap(s);
      if (sale == null) continue;
      if (sale['returned'] == true) continue;
      final ts = _toInt(sale['sold_at']);
      if (ts < todayStart) continue;
      final total = _toDouble(sale['total']);
      canteenTotal += total;
      if ((sale['payment_mode']?.toString() ?? '') == 'upi') {
        canteenUpi += total;
      } else {
        canteenCash += total;
      }
    }

    // ── Pending dues ──────────────────────────────────────────────────────
    final dues = <DueItem>[];
    double duesTotal = 0;
    for (final entry in _duesRaw.entries) {
      final d = _asMap(entry.value);
      if (d == null) continue;
      if (d['paid'] == true) continue;
      final amount = _toDouble(d['amount']);
      duesTotal += amount;
      dues.add(DueItem(
        key: entry.key.toString(),
        customerName: d['customer_name']?.toString() ?? '—',
        pcName: d['pc_name']?.toString() ?? d['pc_id']?.toString() ?? '—',
        amount: amount,
        paid: false,
        createdAt: _toInt(d['created_at']),
      ));
    }
    dues.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // ── Electricity (30-day metre readings) ──────────────────────────────
    List<Map> readings = _metreRaw.whereType<Map>().toList();
    readings.sort((a, b) {
      final da = a['date']?.toString() ?? '';
      final db2 = b['date']?.toString() ?? '';
      return db2.compareTo(da); // descending by date string
    });
    final last30 = readings.take(30).toList();
    double units30 = 0;
    for (int i = 0; i < last30.length - 1; i++) {
      final cur  = _toDouble(last30[i]['reading']);
      final prev = _toDouble(last30[i + 1]['reading']);
      final diff = cur - prev;
      if (diff > 0) units30 += diff;
    }
    final latestReading = last30.isNotEmpty ? _toDouble(last30.first['reading']) : 0.0;

    _stats = DashboardStats(
      activePcSessions: activePcs,
      activePs5Sessions: activePs5,
      todayGamingRevenue: gamingCash + gamingUpi,
      todayCanteenRevenue: canteenTotal,
      todayTotalRevenue: gamingCash + gamingUpi + canteenTotal,
      todayCash: gamingCash + canteenCash,
      todayUpi: gamingUpi + canteenUpi,
      pendingDuesTotal: duesTotal,
      pendingDuesCount: dues.length,
      electricityCost30d: units30 * electricityRate,
      electricityUnits30d: units30,
      latestMetreReading: latestReading,
      cafeeName: cafeeName,
      electricityRate: electricityRate,
      pcs: pcs,
      ps5s: ps5s,
      dues: dues,
      wheel: wheel,
    );

    // Each section is isolated: a failure in one (bad/unexpected data in a
    // node) must never stop the others from building or prevent
    // notifyListeners() from firing. Previously a single throw in the
    // ledger builder silently left stock and members permanently empty.
    // Stock/members build first since they're the most user-visible.
    try {
      _rebuildStockAndMembers();
    } catch (e) {
      _stockError = e.toString();
    }
    try {
      _rebuildLedger();
    } catch (_) {
      // ledger unavailable this cycle — other sections still render
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STOCK & MEMBERS
  // ═══════════════════════════════════════════════════════════════════════
  void _rebuildStockAndMembers() {
    _stockError = null;
    // Whichever candidate node actually has data wins, in priority order.
    // canteen_items checked first since that's where your real menu data
    // lives — canteen_stock is only where the in-app "Add Item" button
    // writes, so it shouldn't be allowed to shadow real data with a
    // leftover test entry.
    String sourceNodeName = 'canteen_items';
    Map<dynamic, dynamic> stockSource = _canteenItemsAltRaw;
    if (stockSource.isEmpty) {
      sourceNodeName = 'canteen_stock';
      stockSource = _stockRaw;
    }
    if (stockSource.isEmpty) {
      sourceNodeName = 'menu_items';
      stockSource = _menuItemsAltRaw;
    }
    if (stockSource.isEmpty) {
      sourceNodeName = 'menu';
      stockSource = _menuAltRaw;
    }
    if (stockSource.isEmpty) {
      sourceNodeName = 'products';
      stockSource = _productsAltRaw;
    }
    if (stockSource.isEmpty) {
      sourceNodeName = 'items';
      stockSource = _itemsAltRaw;
    }
    if (stockSource.isEmpty) {
      sourceNodeName = 'stock';
      stockSource = _stockAltRaw;
    }
    if (stockSource.isEmpty) {
      sourceNodeName = 'inventory';
      stockSource = _inventoryAltRaw;
    }
    _stockSourceNode = sourceNodeName;

    final stock = <StockItem>[];
    for (final entry in stockSource.entries) {
      final it = _asMap(entry.value);
      if (it == null) continue;
      final hasQtyField = it.containsKey('quantity') ||
          it.containsKey('stock') ||
          it.containsKey('qty') ||
          it.containsKey('count');
      final qtyField = it.containsKey('quantity')
          ? 'quantity'
          : (it.containsKey('stock')
              ? 'stock'
              : (it.containsKey('qty') ? 'qty' : 'count'));
      // Some menu-style records only have name+price with no stock count
      // at all — treat those as always-available instead of "out of
      // stock" (quantity 0 would be misleading for them).
      final quantity = hasQtyField
          ? _toDouble(it['quantity'] ?? it['stock'] ?? it['qty'] ?? it['count'])
          : 999.0;
      stock.add(StockItem(
        key: entry.key.toString(),
        name: (it['name'] ?? it['item_name'] ?? it['title'])?.toString() ?? 'Item',
        quantity: quantity,
        unit: (it['unit'] ?? it['unit_name'])?.toString() ?? 'pcs',
        lowThreshold: _toDouble(
            it['low_threshold'] ?? it['lowThreshold'] ?? it['min_stock'] ?? 5),
        price: _toDouble(it['price'] ?? it['cost'] ?? it['selling_price']),
        sourceNode: sourceNodeName,
        quantityField: qtyField,
        emoji: (it['emoji'] ?? '').toString(),
        category: (it['category'] ?? '').toString(),
      ));
    }
    stock.sort((a, b) => a.name.compareTo(b.name));
    _stock = stock;

    final memberSource = _membersRaw.isNotEmpty
        ? _membersRaw
        : (_membersAltRaw.isNotEmpty ? _membersAltRaw : _membershipAltRaw);
    _membersSourceNode = _membersRaw.isNotEmpty
        ? 'memberships'
        : (_membersAltRaw.isNotEmpty
            ? 'members'
            : (_membershipAltRaw.isNotEmpty ? 'membership' : 'memberships'));

    final members = <MemberInfo>[];
    for (final entry in memberSource.entries) {
      final m = _asMap(entry.value);
      if (m == null) continue;
      members.add(MemberInfo(
        key: entry.key.toString(),
        name: (m['name'] ?? m['customer_name'] ?? m['member_name'])?.toString() ??
            'Unknown',
        phone: (m['phone'] ?? m['mobile'] ?? m['contact'])?.toString() ?? '',
        plan: (m['plan'] ?? m['membership_type'] ?? m['type'])?.toString() ??
            'Standard',
        joinedAt: _toInt(m['joined_at'] ?? m['created_at'] ?? m['start_date']),
        expiresAt:
            _toInt(m['expires_at'] ?? m['expiry_date'] ?? m['valid_until']),
      ));
    }
    members.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    _members = members;
  }

  /// True if a gaming payment record looks like it came from a PS5 rather
  /// than a PC. Checked in order: explicit device_type field, then
  /// presence of a ps5_slot / pc_id key. Defaults to PC if ambiguous.
  bool _isPs5Payment(Map pay) {
    final dt = pay['device_type']?.toString().toLowerCase();
    if (dt != null && dt.isNotEmpty) return dt.contains('ps5');
    if (pay.containsKey('ps5_slot')) return true;
    if (pay.containsKey('pc_id')) return false;
    return false;
  }

  /// Computes a revenue report for an arbitrary [start, end) window from
  /// whatever gaming/canteen/membership data is already cached — no extra
  /// Firebase reads needed since these streams are always live.
  ReportStats computeReport(DateTime start, DateTime end) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    double pcRev = 0, ps5Rev = 0, cashTotal = 0, upiTotal = 0;
    int gamingTx = 0;
    for (final p in _paymentsRaw.values) {
      final pay = _asMap(p);
      if (pay == null) continue;
      final ts = _toInt(pay['paid_at']);
      if (ts < startMs || ts >= endMs) continue;
      final cash = _toDouble(pay['cash']);
      final upi = _toDouble(pay['upi']);
      cashTotal += cash;
      upiTotal += upi;
      gamingTx++;
      if (_isPs5Payment(pay)) {
        ps5Rev += cash + upi;
      } else {
        pcRev += cash + upi;
      }
    }

    double canteenRev = 0;
    int canteenTx = 0;
    for (final s in _salesRaw.values) {
      final sale = _asMap(s);
      if (sale == null) continue;
      if (sale['returned'] == true) continue;
      final ts = _toInt(sale['sold_at']);
      if (ts < startMs || ts >= endMs) continue;
      final total = _toDouble(sale['total']);
      canteenRev += total;
      canteenTx++;
      if ((sale['payment_mode']?.toString() ?? '') == 'upi') {
        upiTotal += total;
      } else {
        cashTotal += total;
      }
    }

    double memRev = 0;
    int memTx = 0;
    for (final m in _membershipRaw.values) {
      final mem = _asMap(m);
      if (mem == null) continue;
      final ts = _toInt(mem['paid_at'] ?? mem['created_at']);
      if (ts < startMs || ts >= endMs) continue;
      final amount = _toDouble(mem['amount']);
      memRev += amount;
      memTx++;
      final mode = mem['payment_mode']?.toString() ?? 'cash';
      if (mode == 'upi') {
        upiTotal += amount;
      } else {
        cashTotal += amount;
      }
    }

    return ReportStats(
      start: start,
      end: end,
      pcRevenue: pcRev,
      ps5Revenue: ps5Rev,
      canteenRevenue: canteenRev,
      membershipRevenue: memRev,
      cashTotal: cashTotal,
      upiTotal: upiTotal,
      gamingTransactions: gamingTx,
      canteenTransactions: canteenTx,
      membershipTransactions: memTx,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PARTNER LEDGER
  // ═══════════════════════════════════════════════════════════════════════
  void _rebuildLedger() {
    // ── All-time gaming income (cash + upi) ─────────────────────────────
    double gamingCashAll = 0, gamingUpiAll = 0;
    for (final p in _paymentsRaw.values) {
      final pay = _asMap(p);
      if (pay == null) continue;
      gamingCashAll += _toDouble(pay['cash']);
      gamingUpiAll  += _toDouble(pay['upi']);
    }
    final gamingIncome = gamingCashAll + gamingUpiAll;

    // ── All-time canteen income (cash + upi) ────────────────────────────
    double canteenCashAll = 0, canteenUpiAll = 0;
    for (final s in _salesRaw.values) {
      final sale = _asMap(s);
      if (sale == null) continue;
      if (sale['returned'] == true) continue;
      final total = _toDouble(sale['total']);
      if ((sale['payment_mode']?.toString() ?? '') == 'upi') {
        canteenUpiAll += total;
      } else {
        canteenCashAll += total;
      }
    }
    final canteenIncome = canteenCashAll + canteenUpiAll;

    // ── All-time membership income (cash + upi) ─────────────────────────
    double membershipCashAll = 0, membershipUpiAll = 0;
    for (final m in _membershipRaw.values) {
      final mem = _asMap(m);
      if (mem == null) continue;
      final amount = _toDouble(mem['amount']);
      final mode = (mem['payment_mode']?.toString() ?? 'cash');
      if (mode == 'upi') {
        membershipUpiAll += amount;
      } else {
        membershipCashAll += amount;
      }
    }
    final membershipIncome = membershipCashAll + membershipUpiAll;

    final totalCashRevenue = gamingCashAll + canteenCashAll + membershipCashAll;

    // ── Mario Gaming expenses (electricity, rent, etc.) ─────────────────
    double totalExpenses = 0;
    final entries = <LedgerEntry>[];
    for (final entry in _expensesRaw.entries) {
      final e = _asMap(entry.value);
      if (e == null) continue;
      final amount = _toDouble(e['amount']);
      totalExpenses += amount;
      entries.add(LedgerEntry(
        key: entry.key.toString(),
        type: 'expense',
        label: e['category']?.toString() ?? 'Expense',
        amount: amount,
        createdAt: _toInt(e['created_at']),
        note: e['note']?.toString(),
      ));
    }

    // ── Business contributions (partners covering a Mario deficit) ──────
    double totalContributions = 0;
    for (final entry in _contributionsRaw.entries) {
      final c = _asMap(entry.value);
      if (c == null) continue;
      final amount = _toDouble(c['amount']);
      totalContributions += amount;
      entries.add(LedgerEntry(
        key: entry.key.toString(),
        type: 'contribution',
        label: 'Business Contribution',
        amount: amount,
        createdAt: _toInt(c['created_at']),
        partnerName: c['partner_name']?.toString(),
        note: c['note']?.toString(),
      ));
    }

    // Mario Gaming's own account: revenue minus its expenses, topped up by contributions.
    final marioGamingBalance = totalCashRevenue - totalExpenses + totalContributions;
    // Only split a positive pool. If Mario Gaming itself is in deficit, there's
    // nothing to distribute until partners contribute it back to positive.
    final perPartnerShare = marioGamingBalance > 0 ? marioGamingBalance / 3 : 0.0;

    // ── Withdrawals per partner ──────────────────────────────────────────
    final withdrawalsByPartner = <String, double>{};
    for (final entry in _withdrawalsRaw.entries) {
      final w = _asMap(entry.value);
      if (w == null) continue;
      final pid = w['partner_id']?.toString() ?? '';
      final amount = _toDouble(w['amount']);
      withdrawalsByPartner[pid] = (withdrawalsByPartner[pid] ?? 0) + amount;
      entries.add(LedgerEntry(
        key: entry.key.toString(),
        type: 'withdrawal',
        label: 'Withdrawal',
        amount: amount,
        createdAt: _toInt(w['created_at']),
        partnerName: w['partner_name']?.toString(),
        note: w['note']?.toString(),
      ));
    }

    // ── Repayments per partner (only ever fixes that same partner) ──────
    final repaymentsByPartner = <String, double>{};
    for (final entry in _repaymentsRaw.entries) {
      final r = _asMap(entry.value);
      if (r == null) continue;
      final pid = r['partner_id']?.toString() ?? '';
      final amount = _toDouble(r['amount']);
      repaymentsByPartner[pid] = (repaymentsByPartner[pid] ?? 0) + amount;
      entries.add(LedgerEntry(
        key: entry.key.toString(),
        type: 'repayment',
        label: 'Repayment',
        amount: amount,
        createdAt: _toInt(r['created_at']),
        partnerName: r['partner_name']?.toString(),
        note: r['note']?.toString(),
      ));
    }

    const partnerIds = ['p1', 'p2', 'p3'];
    final partners = partnerIds.map((id) {
      return PartnerInfo(
        id: id,
        name: partnerNames[id]!,
        shareBase: perPartnerShare,
        withdrawals: withdrawalsByPartner[id] ?? 0,
        repayments: repaymentsByPartner[id] ?? 0,
      );
    }).toList();

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    double totalWithdrawalsAll = 0, totalRepaymentsAll = 0;
    withdrawalsByPartner.forEach((_, v) => totalWithdrawalsAll += v);
    repaymentsByPartner.forEach((_, v) => totalRepaymentsAll += v);

    // Physical cash in the counter right now.
    final counterCash = totalCashRevenue -
        totalExpenses -
        totalWithdrawalsAll +
        totalRepaymentsAll +
        totalContributions;

    _ledger = LedgerStats(
      counterCash: counterCash,
      totalCashRevenue: totalCashRevenue,
      totalExpenses: totalExpenses,
      totalContributions: totalContributions,
      marioGamingBalance: marioGamingBalance,
      gamingIncome: gamingIncome,
      canteenIncome: canteenIncome,
      membershipIncome: membershipIncome,
      partners: partners,
      recentEntries: entries.take(40).toList(),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  void dispose() {
    for (final s in _subs) { s.cancel(); }
    super.dispose();
  }
}