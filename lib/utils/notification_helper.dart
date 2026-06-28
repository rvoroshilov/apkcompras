import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/pantry_item.dart';
import 'constants.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Días de antelación con que se avisa antes de la caducidad.
  static const int daysBefore = 2;

  /// Hora del día (24h) a la que llega el aviso programado.
  static const int notifyHour = 10;

  static Future<void> initialize() async {
    tzdata.initializeTimeZones();
    try {
      // App en español: zona horaria peninsular por defecto.
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    } catch (_) {
      // Si fallara, se queda en UTC (el aviso podría desfasarse alguna hora).
    }

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

  /// Aviso de presupuesto del mes (cerca del límite o superado).
  /// Usa el id 3 (los 1 y 2 son para caducidades inmediatas).
  static Future<void> showBudgetAlert({
    required String title,
    required String body,
  }) async {
    await _showNotification(id: 3, title: title, body: body);
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

  // ── AVISOS PROGRAMADOS POR PRODUCTO ───────────────────────────────────────

  /// IDs 1 y 2 están reservados para los avisos inmediatos (resumen).
  static int _scheduleId(String itemId) => 1000 + (itemId.hashCode & 0x7ffff);

  /// Reprograma los avisos de caducidad de toda la despensa.
  /// Se llama cada vez que se sincronizan los datos, de modo que los avisos
  /// se vuelven a armar tras reiniciar el móvil o al cambiar productos.
  static Future<void> rescheduleExpiryNotifications(
      List<PantryItem> items) async {
    // Cancela los avisos programados previos (mantiene los inmediatos 1 y 2).
    final pending = await _plugin.pendingNotificationRequests();
    for (final req in pending) {
      if (req.id >= 1000) await _plugin.cancel(req.id);
    }

    for (final item in items) {
      await _scheduleForItem(item);
    }
  }

  static Future<void> _scheduleForItem(PantryItem item) async {
    final expiry = item.expiryDate;
    if (expiry == null) return;

    // Avisar [daysBefore] días antes, a las [notifyHour]:00.
    final notifyDay = DateTime(
        expiry.year, expiry.month, expiry.day - daysBefore, notifyHour);
    final scheduled = tz.TZDateTime.from(notifyDay, tz.local);

    // Si ese momento ya pasó, no programamos nada (el resumen al abrir la app
    // ya cubre lo que está por caducar o caducado).
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      _scheduleId(item.id),
      'Caduca pronto ⏳',
      '${item.name} caduca en $daysBefore días',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancela el aviso programado de un producto concreto.
  static Future<void> cancelForItem(String itemId) async {
    await _plugin.cancel(_scheduleId(itemId));
  }
}
