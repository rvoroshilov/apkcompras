import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class WidgetHelper {
  static Future<void> update() async {
    if (!Platform.isAndroid) return;
    try {
      final db = DBHelper();
      final pantry = await db.getPantryItems();
      final now = DateTime.now();
      final alertCount = pantry.where((p) =>
          p.expiryDate != null &&
          p.expiryDate!.difference(now).inDays <= 3).length;
      final lowStockCount = pantry.where((p) => p.isBelowMinStock).length;
      final monthlySpent = await db.getMonthlySpend();
      final budget = await db.getMonthlyBudget();
      final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

      await HomeWidget.saveWidgetData<String>(
          'expiring_count', alertCount.toString());
      await HomeWidget.saveWidgetData<String>(
          'low_stock_count', lowStockCount.toString());
      await HomeWidget.saveWidgetData<String>(
          'monthly_spent', fmt.format(monthlySpent));
      await HomeWidget.saveWidgetData<String>(
          'monthly_budget', budget > 0 ? fmt.format(budget) : '');
      await HomeWidget.updateWidget(
        androidName: 'MiCompraWidgetProvider',
        qualifiedAndroidName:
            'com.example.apkcompras.MiCompraWidgetProvider',
      );
    } catch (_) {}
  }
}
