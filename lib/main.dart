import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'utils/backup_helper.dart';
import 'utils/notification_helper.dart';
import 'utils/widget_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  await BackupHelper.init();
  await NotificationHelper.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseService().init();
  runApp(const App());
  Future.delayed(const Duration(seconds: 3), WidgetHelper.update);
}
