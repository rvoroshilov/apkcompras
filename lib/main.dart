import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'utils/backup_helper.dart';
import 'utils/notification_helper.dart';
import 'utils/widget_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  await BackupHelper.init();
  await NotificationHelper.initialize();
  runApp(const App());
  Future.delayed(const Duration(seconds: 3), WidgetHelper.update);
}
