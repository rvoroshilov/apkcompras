import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum DeviceStatus { pending, approved, blocked }

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  static const _deviceIdKey = 'device_id';
  static const _collection = 'devices';

  String? _deviceId;
  String? get deviceId => _deviceId;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
    await _register();
  }

  Future<void> _register() async {
    if (_deviceId == null) return;
    final doc = _db.collection(_collection).doc(_deviceId);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'deviceId': _deviceId,
        'status': 'pending',
        'registeredAt': FieldValue.serverTimestamp(),
        'uid': FirebaseAuth.instance.currentUser?.uid,
      });
    }
  }

  Stream<DeviceStatus> statusStream() {
    if (_deviceId == null) return const Stream.empty();
    return _db
        .collection(_collection)
        .doc(_deviceId)
        .snapshots()
        .map((snap) => _parse(snap.data()?['status']));
  }

  static DeviceStatus _parse(dynamic value) {
    switch (value) {
      case 'approved':
        return DeviceStatus.approved;
      case 'blocked':
        return DeviceStatus.blocked;
      default:
        return DeviceStatus.pending;
    }
  }
}
