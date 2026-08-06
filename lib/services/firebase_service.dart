import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final _db = FirebaseDatabase.instance;

  // ── Streams (existing) ──────────────────────────────────────────────────

  static Stream<DatabaseEvent> pcsStream() => _db.ref('pcs').onValue;

  static Stream<DatabaseEvent> ps5Stream() => _db.ref('ps5_sessions').onValue;

  static Stream<DatabaseEvent> pendingDuesStream() =>
      _db.ref('pending_dues').onValue;

  static Stream<DatabaseEvent> salesStream() => _db.ref('sales').onValue;

  static Stream<DatabaseEvent> paymentsStream() => _db.ref('payments').onValue;

  static Stream<DatabaseEvent> metreStream() =>
      _db.ref('metre_readings').onValue;

  static Stream<DatabaseEvent> settingsStream() => _db.ref('settings').onValue;

  // ── Streams (Partner Ledger) ────────────────────────────────────────────

  static Stream<DatabaseEvent> membershipStream() =>
      _db.ref('membership_payments').onValue;

  static Stream<DatabaseEvent> marioExpensesStream() =>
      _db.ref('mario_expenses').onValue;

  static Stream<DatabaseEvent> partnerWithdrawalsStream() =>
      _db.ref('partner_withdrawals').onValue;

  static Stream<DatabaseEvent> partnerRepaymentsStream() =>
      _db.ref('partner_repayments').onValue;

  static Stream<DatabaseEvent> businessContributionsStream() =>
      _db.ref('business_contributions').onValue;

  // ── Streams (Stock / Members / Reports) ─────────────────────────────────
  // Different apps name these nodes differently, so we listen on several
  // common candidates and DashboardProvider picks whichever one actually
  // has data. This avoids needing to know your exact Firebase schema.

  static Stream<DatabaseEvent> canteenStockStream() =>
      _db.ref('canteen_stock').onValue;
  static Stream<DatabaseEvent> stockAltStream() => _db.ref('stock').onValue;
  static Stream<DatabaseEvent> inventoryAltStream() =>
      _db.ref('inventory').onValue;
  static Stream<DatabaseEvent> productsAltStream() =>
      _db.ref('products').onValue;
  static Stream<DatabaseEvent> canteenItemsAltStream() =>
      _db.ref('canteen_items').onValue;
  static Stream<DatabaseEvent> menuItemsAltStream() =>
      _db.ref('menu_items').onValue;
  static Stream<DatabaseEvent> menuAltStream() => _db.ref('menu').onValue;
  static Stream<DatabaseEvent> itemsAltStream() => _db.ref('items').onValue;

  static Stream<DatabaseEvent> membershipsStream() =>
      _db.ref('memberships').onValue;
  static Stream<DatabaseEvent> membersAltStream() => _db.ref('members').onValue;
  static Stream<DatabaseEvent> membershipAltStream() =>
      _db.ref('membership').onValue;

  // ── Writers (Partner Ledger) ────────────────────────────────────────────

  /// Records a Mario Gaming operational expense (electricity, rent, etc.)
  /// This is subtracted from counter cash and from the distributable pool.
  static Future<void> addExpense({
    required String category,
    required double amount,
    String note = '',
  }) {
    return _db.ref('mario_expenses').push().set({
      'category': category,
      'amount': amount,
      'note': note,
      'created_at': ServerValue.timestamp,
    });
  }

  /// A partner takes cash out of the counter against their share.
  /// If it exceeds their share, their balance goes negative — tracked
  /// individually per partner_id.
  static Future<void> addWithdrawal({
    required String partnerId,
    required String partnerName,
    required double amount,
    String note = '',
  }) {
    return _db.ref('partner_withdrawals').push().set({
      'partner_id': partnerId,
      'partner_name': partnerName,
      'amount': amount,
      'note': note,
      'created_at': ServerValue.timestamp,
    });
  }

  /// A partner pays cash back into the counter to fix their OWN negative
  /// balance. This must only ever be tied to that partner's own partner_id —
  /// one partner can never repay another partner's balance.
  static Future<void> addRepayment({
    required String partnerId,
    required String partnerName,
    required double amount,
    String note = '',
  }) {
    return _db.ref('partner_repayments').push().set({
      'partner_id': partnerId,
      'partner_name': partnerName,
      'amount': amount,
      'note': note,
      'created_at': ServerValue.timestamp,
    });
  }

  /// Any partner can top up the shared Mario Gaming business account when
  /// it is in deficit (expenses > revenue). This is separate from an
  /// individual partner's own balance repayment.
  static Future<void> addContribution({
    required String partnerId,
    required String partnerName,
    required double amount,
    String note = '',
  }) {
    return _db.ref('business_contributions').push().set({
      'partner_id': partnerId,
      'partner_name': partnerName,
      'amount': amount,
      'note': note,
      'created_at': ServerValue.timestamp,
    });
  }

  /// Marks a pending due as paid. Instead of just flipping a field (which
  /// can silently fail to "disappear" if some other app reads a different
  /// field name), this COPIES the due into a `paid_dues` history node with
  /// a paid_at timestamp, then REMOVES it from `pending_dues` — guaranteed
  /// to vanish from the pending list the moment this succeeds, while still
  /// keeping a record of it.
  static Future<void> markDuePaid(String dueKey, Map<String, dynamic> dueData) async {
    final payload = Map<String, dynamic>.from(dueData);
    payload['paid'] = true;
    payload['paid_at'] = ServerValue.timestamp;
    await _db.ref('paid_dues/$dueKey').set(payload);
    await _db.ref('pending_dues/$dueKey').remove();
  }

  /// Adds a new canteen stock item — always writes to the canonical
  /// `canteen_stock` node, so once you add even one item through the app
  /// this becomes the winning source and stock reliably shows up from then
  /// on, regardless of what any other app calls its stock node.
  /// Adds a new stock/menu item. [node] should be whatever DashboardProvider
  /// says is the currently-active source (`stockSourceNode`) so it lands in
  /// the SAME list your real menu already lives in — not a separate,
  /// invisible list. Writes using your real field names (name/price/stock)
  /// so it matches your existing canteen_items records exactly.
  static Future<void> addStockItem({
    required String node,
    required String name,
    required double quantity,
    required String unit,
    required double price,
    required double lowThreshold,
    String category = '',
    String emoji = '',
  }) {
    return _db.ref(node).push().set({
      'name': name,
      'stock': quantity,
      'unit': unit,
      'price': price,
      'low_threshold': lowThreshold,
      'category': category,
      'emoji': emoji,
      'created_at': ServerValue.timestamp,
    });
  }

  /// Wipes every child under a node — used by the Diagnostics screen to
  /// let you clear out a stray/test node (e.g. an accidental test entry)
  /// directly from the app, no Firebase console needed.
  static Future<void> clearNode(String node) => _db.ref(node).remove();

  /// Increments/decrements a stock item's quantity. [sourceNode] and
  /// [quantityField] tell it exactly which Firebase node/field to write to
  /// (auto-detected by DashboardProvider from whichever node had data).
  /// Never lets quantity go below zero.
  static Future<void> adjustStock(
    String key,
    double delta, {
    String sourceNode = 'canteen_stock',
    String quantityField = 'quantity',
  }) async {
    final ref = _db.ref('$sourceNode/$key/$quantityField');
    final snap = await ref.get();
    final current = (snap.value is num) ? (snap.value as num).toDouble() : 0.0;
    final next = current + delta;
    await ref.set(next < 0 ? 0 : next);
  }

  /// One-time fetch of every top-level Firebase node and its child count —
  /// powers the in-app Diagnostics screen so you can see your REAL database
  /// structure and field names on your own device, without opening the
  /// Firebase console. This is how we find out what your canteen stock /
  /// membership nodes are actually called.
  static Future<Map<String, dynamic>> fetchRootSummary() async {
    final snap = await _db.ref().get();
    final result = <String, dynamic>{};
    if (snap.exists && snap.value is Map) {
      final root = snap.value as Map;
      root.forEach((key, value) {
        int count = 0;
        dynamic sample;
        if (value is Map) {
          count = value.length;
          if (value.isNotEmpty) sample = value.values.first;
        } else if (value is List) {
          final nonNull = value.where((e) => e != null).toList();
          count = nonNull.length;
          if (nonNull.isNotEmpty) sample = nonNull.first;
        }
        result[key.toString()] = {'count': count, 'sample': sample};
      });
    }
    return result;
  }

  /// Sets a specific partner's password (used to gate Withdraw/Repay).
  static Future<void> setPartnerPassword(String partnerId, String newPassword) {
    return _db.ref('settings/partnerPasswords/$partnerId').set(newPassword);
  }

  /// Sets the password required to add a Mario Gaming expense.
  static Future<void> setExpensePassword(String newPassword) {
    return _db.ref('settings/expensePassword').set(newPassword);
  }

  /// Renames a partner. Stored in settings so every device picks it up
  /// live — the Partner Ledger reads these same keys.
  static Future<void> setPartnerName(String partnerId, String newName) {
    final key = partnerId == 'p1'
        ? 'partner1Name'
        : (partnerId == 'p2' ? 'partner2Name' : 'partner3Name');
    return _db.ref('settings/$key').set(newName);
  }

  /// Permanently removes a pending due. Unlike "mark paid" (which archives
  /// it into paid_dues), this deletes it outright with no record — meant
  /// for correcting mistaken entries, so it's password-gated in the UI.
  static Future<void> deleteDue(String dueKey) {
    return _db.ref('pending_dues/$dueKey').remove();
  }

  /// the currently-active source node (`membersSourceNode`) so the new
  /// member lands in the SAME list your existing members are already in,
  /// instead of accidentally starting a second, invisible list.
  static Future<void> addMember({
    required String node,
    required String name,
    required String phone,
    required String plan,
    required int expiresAt, // 0 = no expiry
  }) {
    return _db.ref(node).push().set({
      'name': name,
      'phone': phone,
      'plan': plan,
      'joined_at': ServerValue.timestamp,
      'expires_at': expiresAt,
    });
  }

  /// Deactivates a member immediately by setting their expiry to right now
  /// — no new field required, works with the existing expires_at model.
  static Future<void> deactivateMember(String node, String key) {
    return _db.ref('$node/$key/expires_at').set(DateTime.now().millisecondsSinceEpoch);
  }

  /// Convert a snapshot map (keyed or list) to a List<Map>
  static List<Map<dynamic, dynamic>> snapToList(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return [];
    final v = snap.value;
    if (v is Map) return v.values.whereType<Map>().toList();
    if (v is List) return v.whereType<Map>().toList();
    return [];
  }

  static Map<String, dynamic> snapToMap(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return {};
    final v = snap.value;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return {};
  }
}