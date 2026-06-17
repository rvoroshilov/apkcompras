import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEntry {
  final String id;
  final String type;
  final String name;
  final String userName;
  final DateTime timestamp;

  const ActivityEntry({
    required this.id,
    required this.type,
    required this.name,
    required this.userName,
    required this.timestamp,
  });

  String get description {
    final who = userName.isNotEmpty ? userName : 'Alguien';
    return switch (type) {
      'added_pantry' => '$who añadió "$name" a la despensa',
      'deleted_pantry' => '$who eliminó "$name" de la despensa',
      'completed_list' => '$who completó la lista "$name"',
      'added_item' => '$who añadió "$name" a la compra',
      'joined_house' => '$who se unió a la casa',
      _ => '$who: $name',
    };
  }

  factory ActivityEntry.fromMap(Map<String, dynamic> map, String id) {
    final tsRaw = map['timestamp'];
    final DateTime ts;
    if (tsRaw is Timestamp) {
      ts = tsRaw.toDate();
    } else if (tsRaw is String) {
      ts = DateTime.parse(tsRaw);
    } else {
      ts = DateTime.now();
    }
    return ActivityEntry(
      id: id,
      type: (map['type'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      userName: (map['user_name'] as String?) ?? '',
      timestamp: ts,
    );
  }
}
