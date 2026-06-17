import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static const _houseKey = 'house_id';
  static const _nameKey = 'user_display_name';

  FirebaseFirestore get db => FirebaseFirestore.instance;

  String? _houseId;
  String? _displayName;

  String? get houseId => _houseId;
  String? get houseCode => _houseId?.substring(0, 6).toUpperCase();
  String? get displayName => _displayName;
  String get userId => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      db.collection('households').doc(_houseId).collection(name);

  Future<void> init() async {
    // Firebase.initializeApp() is already called in main.dart before this runs.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final prefs = await SharedPreferences.getInstance();
    _houseId = prefs.getString(_houseKey);
    if (_houseId == null) {
      await createNewHouse();
    }
    _displayName = prefs.getString(_nameKey);
    if (_displayName != null) {
      _updateMembership().ignore();
    }
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _displayName!);
    await _updateMembership();
  }

  Future<void> _updateMembership() async {
    if (_houseId == null) return;
    await db.collection('households').doc(_houseId).collection('members').doc(userId).set({
      'name': _displayName ?? 'Miembro',
      'last_seen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getMembers() async {
    if (_houseId == null) return [];
    final snap = await db.collection('households').doc(_houseId!).collection('members').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> createNewHouse() async {
    final doc = db.collection('households').doc();
    _houseId = doc.id;
    await doc.set({'created_at': FieldValue.serverTimestamp()});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_houseKey, _houseId!);
    if (_displayName != null) _updateMembership().ignore();
  }

  Future<bool> joinHouse(String code) async {
    // Find household where doc ID starts with the 6-char code (case insensitive)
    final snapshot = await db.collection('households').get();
    for (final doc in snapshot.docs) {
      if (doc.id.toUpperCase().startsWith(code.toUpperCase())) {
        _houseId = doc.id;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_houseKey, _houseId!);
        if (_displayName != null) await _updateMembership();
        return true;
      }
    }
    return false;
  }

  Future<String?> getCurrentHouseId() async {
    if (_houseId != null) return _houseId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_houseKey);
  }

  Future<void> leaveHouse() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_houseKey);
    _houseId = null;
    await createNewHouse();
  }
}
