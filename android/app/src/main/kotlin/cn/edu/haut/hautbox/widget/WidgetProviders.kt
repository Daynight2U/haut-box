package cn.edu.haut.hautbox.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle

/** 2×2：下一节课 */
class NextClassWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, WidgetRenderer.buildNext(context, id))
        }
        WidgetRenderer.scheduleTick(context)
    }

    /** 用户拉伸/压缩组件时重建（小米、OPPO 都会触发） */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, WidgetRenderer.buildNext(context, appWidgetId))
    }

    override fun onEnabled(context: Context) {
        WidgetRenderer.updateAll(context)
    }
}

/** 4×2：今日课表 */
class TodayWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, WidgetRenderer.buildToday(context, id))
        }
        WidgetRenderer.scheduleTick(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, WidgetRenderer.buildToday(context, appWidgetId))
    }

    override fun onEnabled(context: Context) {
        WidgetRenderer.updateAll(context)
    }
}

/** 定时 / 开机 / 改时间 → 刷新所有组件 */
class WidgetTickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WidgetRenderer.ACTION_TICK,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_DATE_CHANGED,
            -> WidgetRenderer.updateAll(context)
        }
    }
}
