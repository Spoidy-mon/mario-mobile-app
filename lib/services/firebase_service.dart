import 'package:firebase_database/firebase_database.dart';
import 'canteen_cart_line.dart';

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

  /// Live stream of the single wheel device.
  static Stream<DatabaseEvent> wheelStream() => _db.ref('wheel_sessions').onValue;

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

  // ── Writers (Sessions) ───────────────────────────────────────────────────

  /// Starts a session on a PC, the Wheel, or a PS5 — writes straight to
  /// the same node the desktop client reads from, using .update() so
  /// existing fields (id, name, slot) on that node are left untouched.
  /// ALSO pushes (or merges into) a pending due for the session amount —
  /// without this, the charge only ever lived as a field on the device
  /// node and never actually showed up on the Dues screen.
  static Future<void> startSession({
    required String node, // e.g. 'pcs/3', 'wheel_sessions/w1', 'ps5_sessions/2'
    required String deviceName, // friendly label, e.g. 'PC-3', 'Wheel', 'PS5 #2'
    required String customerName,
    required int minutes,
    required double amount, // regular session price, recorded on the device node
    double? dueAmount, // what actually gets charged to their due — defaults
                        // to [amount]; pass 0 for a member session that's
                        // covered by their membership instead of billed
    String? note, // overrides the default "$minutes min session" due label
    int players = 1,
    bool isMember = false,
    String memberPlan = '',
  }) async {
    await _db.ref(node).update({
      'status': 'active',
      'customer_name': customerName,
      'time_remaining': minutes * 60, // stored in seconds
      'session_amount': amount,
      'players': players,
      'payment_status': (dueAmount ?? amount) <= 0 ? 'covered' : 'pending',
      'is_paused': false,
      'is_member': isMember,
      'member_plan': memberPlan,
      'started_at': ServerValue.timestamp,
    });

    await _addOrMergeDue(
      customerName: customerName,
      pcName: deviceName,
      amount: dueAmount ?? amount,
      itemLabel: note ?? '$minutes min session',
      source: 'gaming',
      isMember: isMember,
      memberPlan: memberPlan,
    );
  }

  /// Adds a charge to a customer's tab — merging into their existing
  /// unpaid due for the same PC/device if one already exists (so a
  /// canteen snack bought mid-session and the session charge itself land
  /// in ONE combined bill instead of two separate due entries), or
  /// starting a new due if this is their first charge. Shared by both
  /// `startSession` (gaming time) and `sellCanteenItems` (food/drinks).
  static Future<void> _addOrMergeDue({
    required String customerName,
    required String pcName,
    required double amount,
    required String itemLabel,
    required String source,
    bool isMember = false,
    String memberPlan = '',
  }) async {
    String? existingKey;
    double existingAmount = 0;
    String existingItems = '';

    final snap = await _db.ref('pending_dues').get();
    if (snap.exists && snap.value is Map) {
      (snap.value as Map).forEach((key, value) {
        if (existingKey != null) return; // already found a match
        if (value is! Map) return;
        if (value['paid'] == true) return;

        final duePc = value['pc_name']?.toString() ?? '';
        final dueCustomer = value['customer_name']?.toString() ?? '';

        final matchesByPc = pcName.isNotEmpty && duePc == pcName;
        final matchesByNameOnly = pcName.isEmpty && dueCustomer == customerName;

        if (matchesByPc || matchesByNameOnly) {
          existingKey = key.toString();
          existingAmount =
              (value['amount'] is num) ? (value['amount'] as num).toDouble() : 0.0;
          existingItems = value['items']?.toString() ?? '';
        }
      });
    }

    if (existingKey != null) {
      final mergedItems =
          existingItems.isEmpty ? itemLabel : '$existingItems, $itemLabel';
      await _db.ref('pending_dues/$existingKey').update({
        'amount': existingAmount + amount,
        'items': mergedItems,
        'customer_name': customerName,
        if (pcName.isNotEmpty) 'pc_name': pcName,
        if (isMember) 'is_member': true,
        if (memberPlan.isNotEmpty) 'member_plan': memberPlan,
      });
    } else {
      await _db.ref('pending_dues').push().set({
        'customer_name': customerName,
        'pc_name': pcName,
        'amount': amount,
        'items': itemLabel,
        'source': source,
        'is_member': isMember,
        'member_plan': memberPlan,
        'paid': false,
        'created_at': ServerValue.timestamp,
      });
    }
  }

  /// Ends a session — frees the PC/Wheel/PS5 back to idle. Does NOT touch
  /// any due; the session amount was already added to the customer's tab
  /// when it started, so ending it early just stops the timer and clears
  /// the device, without silently changing what they owe.
  static Future<void> endSession(String node) {
    return _db.ref(node).update({
      'status': 'offline',
      'is_paused': false,
      'time_remaining': 0,
      'customer_name': '',
      'payment_status': '',
      'is_member': false,
      'member_plan': '',
      'ended_at': ServerValue.timestamp,
    });
  }

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

  /// Sells one or more canteen items. If [chargeToCustomerName] is given
  /// (an active PC/PS5 customer), the total is added to their tab. If a
  /// PENDING due already exists for that same PC (or, when no PC is given,
  /// the same customer name), the canteen amount is MERGED into that same
  /// due — so a PC's gaming time and their canteen snacks show up as one
  /// combined bill, not two separate line items. Only creates a new due
  /// entry if nothing matching exists yet.
  ///
  /// If [chargeToCustomerName] is null, it's an immediate walk-in cash/UPI
  /// sale and gets written straight to `sales` for today's revenue.
  ///
  /// Either way, each item's stock is decremented by the quantity sold.
  static Future<void> sellCanteenItems({
    required List<CanteenCartLine> items,
    String? chargeToCustomerName,
    String? chargeToPcName,
    String paymentMode = 'cash',
  }) async {
    final total = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final itemsSummary =
        items.map((i) => '${i.name} x${i.quantity}').join(', ');

    if (chargeToCustomerName != null && chargeToCustomerName.isNotEmpty) {
      await _addOrMergeDue(
        customerName: chargeToCustomerName,
        pcName: chargeToPcName ?? '',
        amount: total,
        itemLabel: itemsSummary,
        source: 'canteen',
      );
    } else {
      // Walk-in — paid on the spot (cash or UPI), counts as today's
      // canteen revenue. pc_name is optional here — just a reporting tag,
      // doesn't affect any due.
      await _db.ref('sales').push().set({
        'items': itemsSummary,
        'total': total,
        'payment_mode': paymentMode,
        if (chargeToPcName != null && chargeToPcName.isNotEmpty)
          'pc_name': chargeToPcName,
        'returned': false,
        'sold_at': ServerValue.timestamp,
      });
    }

    // Decrement stock for every item sold, regardless of charge type.
    for (final item in items) {
      await adjustStock(
        item.stockKey,
        item.quantity.toDouble() * -1,
        sourceNode: item.sourceNode,
        quantityField: item.quantityField,
      );
    }
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

  /// Adds a new member. [node] should be whatever DashboardProvider says is
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