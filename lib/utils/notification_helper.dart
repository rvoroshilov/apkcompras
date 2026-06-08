import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/pantry_item.dart';
import 'constants.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            AppConstants.notificationChannelId,
            AppConstants.notificationChannelName,
            description: AppConstants.notificationChannelDesc,
            importance: Importance.high,
          ),
        );
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> checkExpiringItems(List<PantryItem> items) async {
    final expiring =
        items.where((i) => i.isExpiringSoon || i.isExpired).toList();

    if (expiring.isEmpty) return;

    final expired = expiring.where((i) => i.isExpired).toList();
    final soonList = expiring.where((i) => i.isExpiringSoon).toList();

    if (expired.isNotEmpty) {
      await _showNotification(
        id: 1,
        title: '¡Productos caducados! 🚨',
        body: expired.length == 1
            ? '${expired.first.name} ha caducado'
            : '${expired.length} productos han caducado en tu despensa',
      );
    }

    if (soonList.isNotEmpty) {
      await _showNotification(
        id: 2,
        title: 'Productos próximos a caducar ⚠️',
        body: soonList.length == 1
            ? '${soonList.first.name} caduca en ${soonList.first.daysUntilExpiry} días'
            : '${soonList.length} productos caducan pronto',
      );
    }
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }
}
