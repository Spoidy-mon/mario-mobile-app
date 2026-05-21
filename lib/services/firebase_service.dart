import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final _db = FirebaseDatabase.instance;

  // ── Streams ──────────────────────────────────────────────────────────────

  static Stream<DatabaseEvent> pcsStream() =>
      _db.ref('pcs').onValue;

  static Stream<DatabaseEvent> ps5Stream() =>
      _db.ref('ps5_sessions').onValue;

  static Stream<DatabaseEvent> pendingDuesStream() =>
      _db.ref('pending_dues').onValue;

  static Stream<DatabaseEvent> salesStream() =>
      _db.ref('sales').onValue;

  static Stream<DatabaseEvent> paymentsStream() =>
      _db.ref('payments').onValue;

  static Stream<DatabaseEvent> metreStream() =>
      _db.ref('metre_readings').onValue;

  static Stream<DatabaseEvent> settingsStream() =>
      _db.ref('settings').onValue;

  // ── Helpers ──────────────────────────────────────────────────────────────

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
