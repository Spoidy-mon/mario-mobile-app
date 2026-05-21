import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';
import 'dashboard_model.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardStats _stats = const DashboardStats();
  bool _loading = true;
  String? _error;

  DashboardStats get stats => _stats;
  bool get loading => _loading;
  String? get error => _error;

  // Raw caches — rebuilt whenever any stream fires
  Map<dynamic, dynamic> _pcsRaw = {};
  Map<dynamic, dynamic> _ps5Raw = {};
  Map<dynamic, dynamic> _duesRaw = {};
  Map<dynamic, dynamic> _salesRaw = {};
  Map<dynamic, dynamic> _paymentsRaw = {};
  List<dynamic> _metreRaw = [];
  Map<dynamic, dynamic> _settingsRaw = {};

  final List<StreamSubscription> _subs = [];

  void init() {
    _subs.add(FirebaseService.pcsStream().listen(_onPcs, onError: _onErr));
    _subs.add(FirebaseService.ps5Stream().listen(_onPs5, onError: _onErr));
    _subs.add(FirebaseService.pendingDuesStream().listen(_onDues, onError: _onErr));
    _subs.add(FirebaseService.salesStream().listen(_onSales, onError: _onErr));
    _subs.add(FirebaseService.paymentsStream().listen(_onPayments, onError: _onErr));
    _subs.add(FirebaseService.metreStream().listen(_onMetre, onError: _onErr));
    _subs.add(FirebaseService.settingsStream().listen(_onSettings, onError: _onErr));
  }

  void _onErr(dynamic e) {
    _error = e.toString();
    _loading = false;
    notifyListeners();
  }

  void _onPcs(DatabaseEvent e) {
    _pcsRaw = (e.snapshot.value as Map?) ?? {};
    _rebuild();
  }

  void _onPs5(DatabaseEvent e) {
    _ps5Raw = (e.snapshot.value as Map?) ?? {};
    _rebuild();
  }

  void _onDues(DatabaseEvent e) {
    _duesRaw = (e.snapshot.value as Map?) ?? {};
    _rebuild();
  }

  void _onSales(DatabaseEvent e) {
    _salesRaw = (e.snapshot.value as Map?) ?? {};
    _rebuild();
  }

  void _onPayments(DatabaseEvent e) {
    _paymentsRaw = (e.snapshot.value as Map?) ?? {};
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
    _settingsRaw = (e.snapshot.value as Map?) ?? {};
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
    int activePcs = 0;
    for (final entry in _pcsRaw.entries) {
      final pc = entry.value as Map?;
      if (pc == null) continue;
      final status = pc['status']?.toString() ?? 'offline';
      final isPaused = pc['is_paused'] == true;
      final timeRem = _toInt(pc['time_remaining']);
      if (status == 'active') activePcs++;
      pcs.add(PcStatus(
        id: _toInt(pc['id']),
        name: pc['name']?.toString() ?? 'PC-?',
        status: status,
        isPaused: isPaused,
        timeRemaining: timeRem,
        customerName: pc['customer_name']?.toString() ?? '',
        paymentStatus: pc['payment_status']?.toString() ?? '',
      ));
    }
    pcs.sort((a, b) => a.id.compareTo(b.id));

    // ── PS5 ───────────────────────────────────────────────────────────────
    final ps5s = <Ps5Status>[];
    int activePs5 = 0;
    for (final entry in _ps5Raw.entries) {
      final s = entry.value as Map?;
      if (s == null) continue;
      final status = s['status']?.toString() ?? 'offline';
      if (status == 'active') activePs5++;
      ps5s.add(Ps5Status(
        slot: _toInt(s['slot']),
        status: status,
        isPaused: s['is_paused'] == true,
        timeRemaining: _toInt(s['time_remaining']),
        customerName: s['customer_name']?.toString() ?? '',
        paymentStatus: s['payment_status']?.toString() ?? '',
      ));
    }
    ps5s.sort((a, b) => a.slot.compareTo(b.slot));

    // ── Today's payments (gaming) ─────────────────────────────────────────
    double gamingCash = 0, gamingUpi = 0;
    for (final p in _paymentsRaw.values) {
      final pay = p as Map?;
      if (pay == null) continue;
      final ts = _toInt(pay['paid_at']);
      if (ts < todayStart) continue;
      gamingCash += _toDouble(pay['cash']);
      gamingUpi  += _toDouble(pay['upi']);
    }

    // ── Today's canteen sales ─────────────────────────────────────────────
    double canteenTotal = 0, canteenCash = 0, canteenUpi = 0;
    for (final s in _salesRaw.values) {
      final sale = s as Map?;
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
      final d = entry.value as Map?;
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
    // metre_readings stored newest-first (or sorted by date desc)
    List<Map> readings = _metreRaw
        .whereType<Map>()
        .toList();
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
    );

    notifyListeners();
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
