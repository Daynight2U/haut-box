package cn.edu.haut.hautbox.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import cn.edu.haut.hautbox.MainActivity
import cn.edu.haut.hautbox.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * 小组件渲染 + 刷新调度。
 *
 * 适配各家启动器的几个关键点：
 *   - 只使用 RemoteViews 白名单里的控件（LinearLayout / TextView / ImageView），
 *     所以没有真模糊，用半透明纯色 + 圆角 + 强调色条来贴近 App 的观感；
 *   - `targetCellWidth/Height`（Android 12+）让 MIUI/HyperOS、ColorOS、OriginOS
 *     按 2×2 / 4×2 正确占位，而不是被拉伸成 3×2；
 *   - `previewLayout` 让 vivo / OPPO 的选择器里显示真实预览，而不是白块；
 *   - 文字尺寸按实际高度动态设置（setTextViewTextSize），
 *     因为小米会把 2×2 塞进 165dp 的盒子里、原生则是 110dp；
 *   - 刷新不用 updatePeriodMillis（各家中最低 30 分钟，且经常被忽略），
 *     改用 AlarmManager 卡在上下课时刻，用 setAndAllowWhileIdle 免掉精确闹钟权限。
 */
object WidgetRenderer {

    const val ACTION_TICK = "cn.edu.haut.hautbox.WIDGET_TICK"
    private const val REQ_TICK = 9001

    private val WEEK_CN = arrayOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")

    fun updateAll(ctx: Context) {
        val mgr = AppWidgetManager.getInstance(ctx)
        val next = ComponentName(ctx, NextClassWidget::class.java)
        for (id in mgr.getAppWidgetIds(next)) {
            mgr.updateAppWidget(id, buildNext(ctx, id))
        }
        val today = ComponentName(ctx, TodayWidget::class.java)
        for (id in mgr.getAppWidgetIds(today)) {
            mgr.updateAppWidget(id, buildToday(ctx, id))
        }
        scheduleTick(ctx)
    }

    // ---------------------------------------------------------------- 2×2 下一节
    fun buildNext(ctx: Context, widgetId: Int): RemoteViews {
        val rv = RemoteViews(ctx.packageName, R.layout.widget_next)
        val night = isNight(ctx)
        applySkin(
            ctx, rv, night,
            primary = intArrayOf(R.id.tvName),
            secondary = intArrayOf(R.id.tvTime, R.id.tvStatus),
            tertiary = intArrayOf(R.id.tvRoom),
        )

        val (w, h) = sizeOf(ctx, widgetId)
        val compact = h < 120 || w < 120
        rv.setTextViewTextSize(
            R.id.tvName, TypedValue.COMPLEX_UNIT_SP, if (compact) 14.5f else 16f,
        )

        val data = WidgetData.load(ctx)
        if (data == null) {
            rv.setTextViewText(R.id.tvStatus, "尚未同步")
            rv.setTextViewText(R.id.tvName, "打开 App 同步课表")
            rv.setTextViewText(R.id.tvTime, "")
            rv.setTextViewText(R.id.tvRoom, "")
            bindClick(ctx, rv)
            return rv
        }

        val now = Calendar.getInstance()
        val ups = data.upcoming(now)
        val ongoing = ups.firstOrNull { !it.start.after(now) }
        val occ = ongoing ?: ups.firstOrNull()

        if (occ == null) {
            val week = data.weekOf(now)
            rv.setTextViewText(R.id.tvStatus, if (week in 1..30) "第 $week 周" else "假期中")
            rv.setTextViewText(R.id.tvName, "最近没有课")
            rv.setTextViewText(R.id.tvTime, "")
            rv.setTextViewText(R.id.tvRoom, "")
            bindClick(ctx, rv)
            return rv
        }

        val sameDay = occ.start.get(Calendar.DAY_OF_YEAR) == now.get(Calendar.DAY_OF_YEAR)
        val dayPrefix = when {
            occ.dayOffset == 0 -> ""
            occ.dayOffset == 1 -> "明天 "
            else -> "周" + "一二三四五六日"[occ.start.get(Calendar.DAY_OF_WEEK).let {
                if (it == Calendar.SUNDAY) 6 else it - 2
            }] + " "
        }

        val status = when {
            occ.start.after(now) && sameDay -> {
                val m = occ.minutesTo(now)
                if (m >= 60) {
                    "下一节 · " + (m / 60) + " 小时 " + (m % 60) + " 分后"
                } else {
                    "下一节 · $m 分钟后"
                }
            }
            occ.start.after(now) -> "下一节 · $dayPrefix"
            else -> {
                val m = occ.remainMinutes(now)
                if (m <= 0) "刚刚下课" else "正在上课 · 还剩 $m 分钟"
            }
        }

        rv.setTextViewText(R.id.tvStatus, status)
        rv.setTextViewText(R.id.tvName, occ.name)
        rv.setTextViewText(
            R.id.tvTime,
            (if (occ.dayOffset == 1) "明天 " else "") + hm(occ.start) + " - " + hm(occ.end),
        )
        rv.setTextViewText(R.id.tvRoom, occ.room.ifBlank { "" })
        if (occ.room.isBlank()) rv.setViewVisibility(R.id.tvRoom, View.GONE)
        bindClick(ctx, rv)
        return rv
    }

    // ---------------------------------------------------------------- 4×2 今日
    fun buildToday(ctx: Context, widgetId: Int): RemoteViews {
        val rv = RemoteViews(ctx.packageName, R.layout.widget_today)
        val night = isNight(ctx)
        applySkin(
            ctx, rv, night,
            primary = intArrayOf(R.id.tvHeader),
            secondary = intArrayOf(),
            tertiary = intArrayOf(R.id.tvWeek, R.id.tvEmpty),
        )
        rv.removeAllViews(R.id.llRows)

        val data = WidgetData.load(ctx)
        val now = Calendar.getInstance()
        val weekday = (now.get(Calendar.DAY_OF_WEEK) + 5) % 7
        val header = "今天 · " + WEEK_CN[weekday]

        if (data == null) {
            rv.setTextViewText(R.id.tvHeader, header)
            rv.setTextViewText(R.id.tvWeek, "")
            rv.setViewVisibility(R.id.tvEmpty, View.VISIBLE)
            rv.setTextViewText(R.id.tvEmpty, "打开 App 同步课表")
            bindClick(ctx, rv)
            return rv
        }

        val week = data.weekOf(now)
        rv.setTextViewText(R.id.tvHeader, header)
        rv.setTextViewText(R.id.tvWeek, if (week in 1..30) "第 $week 周" else "假期")

        val all = data.today(now)
        val left = all.filter { it.end.after(now) }

        val (_, h) = sizeOf(ctx, widgetId)
        val maxRows = when {
            h < 120 -> 3
            h < 170 -> 5
            else -> all.size
        }

        if (left.isEmpty()) {
            rv.setViewVisibility(R.id.tvEmpty, View.VISIBLE)
            rv.setTextViewText(
                R.id.tvEmpty,
                if (all.isEmpty()) "今天没课，休息一下" else "今天的课上完了",
            )
        } else {
            rv.setViewVisibility(R.id.tvEmpty, View.GONE)
            for (o in left.take(maxRows)) {
                val row = RemoteViews(ctx.packageName, R.layout.widget_row)
                row.setTextViewText(R.id.rowTime, hm(o.start))
                row.setTextViewText(R.id.rowName, o.name)
                row.setTextViewText(R.id.rowRoom, o.room)
                row.setTextColor(R.id.rowName, if (night) 0xFFE8EDF8.toInt() else 0xFF10131C.toInt())
                row.setTextColor(R.id.rowTime, if (night) 0xFF8A93A8.toInt() else 0xFF8D96A8.toInt())
                row.setTextColor(R.id.rowRoom, if (night) 0xFF8A93A8.toInt() else 0xFF8D96A8.toInt())
                rv.addView(R.id.llRows, row)
            }
        }
        bindClick(ctx, rv)
        return rv
    }

    // ---------------------------------------------------------------- 皮肤
    // 只给「当前布局里真实存在」的控件设色：给不存在的 id 排 action 会在桌面
    // 应用 RemoteViews 时抛 ActionException，组件直接白块。
    private fun applySkin(
        ctx: Context,
        rv: RemoteViews,
        night: Boolean,
        primary: IntArray,
        secondary: IntArray,
        tertiary: IntArray,
    ) {
        rv.setInt(
            R.id.root, "setBackgroundResource",
            if (night) R.drawable.widget_bg_dark else R.drawable.widget_bg_light,
        )
        val cPrimary = if (night) 0xFFF3F6FF.toInt() else 0xFF10131C.toInt()
        val cSecondary = if (night) 0xFFC7D0E4.toInt() else 0xFF5B6579.toInt()
        val cTertiary = if (night) 0xFF8A93A8.toInt() else 0xFF8D96A8.toInt()
        for (id in primary) rv.setTextColor(id, cPrimary)
        for (id in secondary) rv.setTextColor(id, cSecondary)
        for (id in tertiary) rv.setTextColor(id, cTertiary)
    }

    private fun bindClick(ctx: Context, rv: RemoteViews) {
        val i = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            ctx, 0, i,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        rv.setOnClickPendingIntent(R.id.root, pi)
    }

    // ---------------------------------------------------------------- 尺寸
    private fun sizeOf(ctx: Context, widgetId: Int): Pair<Int, Int> {
        val opts: Bundle = runCatching {
            AppWidgetManager.getInstance(ctx).getAppWidgetOptions(widgetId)
        }.getOrNull() ?: Bundle()
        val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return (if (w == 0) 110 else w) to (if (h == 0) 110 else h)
    }

    private fun isNight(ctx: Context): Boolean =
        (ctx.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    private fun hm(c: Calendar): String =
        SimpleDateFormat("HH:mm", Locale.getDefault()).format(c.time)

    // ---------------------------------------------------------------- 定时刷新
    /**
     * 卡在下一个「上课 / 下课」时刻刷一次。用 setAndAllowWhileIdle：
     * 不需要精确闹钟权限，最多晚几分钟，桌面组件不需要秒级精度。
     */
    fun scheduleTick(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val target = nextBoundary(ctx)
        val i = Intent(ctx, WidgetTickReceiver::class.java).setAction(ACTION_TICK)
        val pi = PendingIntent.getBroadcast(
            ctx, REQ_TICK, i,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        runCatching { am.cancel(pi) }
        runCatching { am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pi) }
    }

    private fun nextBoundary(ctx: Context): Long {
        val now = Calendar.getInstance()
        val data = WidgetData.load(ctx)
        val nextMidnight = (WidgetData.atMidnight(now)).apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.MINUTE, 5)
        }.timeInMillis

        if (data != null) {
            val ups = data.upcoming(now)
            val candidates = ArrayList<Long>()
            ups.firstOrNull()?.let { candidates.add(it.start.timeInMillis) }
            ups.firstOrNull { !it.start.after(now) }?.let { candidates.add(it.end.timeInMillis) }
            val soonest = candidates.filter { it > now.timeInMillis }.minOrNull()
            if (soonest != null) return minOf(soonest + 1000, nextMidnight)
        }
        return nextMidnight
    }
}
