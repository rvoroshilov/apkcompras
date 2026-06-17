import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_entry.dart';
import 'firebase_service.dart';

class ActivityService {
  static final ActivityService _instance = ActivityService._internal();
  factory ActivityService() => _instance;
  ActivityService._internal();

  Future<void> log(String type, String name) async {
    final fs = FirebaseService();
    if (fs.houseId == null) return;
    try {
      await fs.collection('activity').add({
        'type': type,
        'name': name,
        'user_name': fs.displayName ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Activity logging is best-effort — never let it break the main flow
    }
  }

  Stream<List<ActivityEntry>> stream() {
    final fs = FirebaseService();
    if (fs.houseId == null) return const Stream.empty();
    return fs
        .collection('activity')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ActivityEntry.fromMap(d.data(), d.id))
            .toList());
  }
}
