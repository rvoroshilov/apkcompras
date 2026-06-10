package com.example.apkcompras

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class MiCompraWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.micompra_widget)

            val spent = prefs.getString("monthly_spent", null) ?: "€0,00"
            val budget = prefs.getString("monthly_budget", "") ?: ""
            val expiringCount = prefs.getString("expiring_count", "0")?.toIntOrNull() ?: 0
            val lowStockCount = prefs.getString("low_stock_count", "0")?.toIntOrNull() ?: 0

            views.setTextViewText(R.id.tv_spent, spent)
            views.setTextViewText(
                R.id.tv_budget,
                if (budget.isNotEmpty()) "de $budget" else "este mes"
            )

            val alertParts = mutableListOf<String>()
            if (expiringCount > 0) alertParts.add("⚠ $expiringCount caducan pronto")
            if (lowStockCount > 0) alertParts.add("📦 $lowStockCount stock bajo")
            views.setTextViewText(
                R.id.tv_alert,
                if (alertParts.isEmpty()) "Despensa OK ✓" else alertParts.joinToString(" · ")
            )

            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT
                            or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
