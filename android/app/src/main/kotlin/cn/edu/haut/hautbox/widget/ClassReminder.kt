package cn.edu.haut.hautbox.widget

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import cn.edu.haut.hautbox.MainActivity
import cn.edu.haut.hautbox.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * 课前提醒 + 成绩更新提醒。
 *
 * 全部原生实现，复用桌面组件那份「日程快照」：
 *   - 快照一更新就重排一遍闹钟（今天+明天的课，最多 20 个）
 *   - 用 setAndAllowWhileIdle，不申请精确闹钟权限（晚几分钟无所谓，提前量留了 12 分钟）
 *   - 提醒时间点 = 上课前 12 分钟
 */
object ClassReminder {

    private const val PREFS = "haut_widget"
    private const val KEY_IDS = "reminder_ids"
    private const val KEY_ENABLED = "reminders_enabled"
    const val CH_CLASS = "haut_class_remind"
    const val CH_GRADE = "haut_grade_news"

    private const val LEAD_MINUTES = 12

    fun enabled(ctx: Context): Boolean =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, true)

    fun setEnabled(ctx: Context, on: Boolean) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ENABLED, on).apply()
        if (on) reschedule(ctx) else cancelAll(ctx)
    }

    /** 按最新快照重排提醒。幂等，可反复调用。 */
    fun reschedule(ctx: Context) {
        cancelAll(ctx)
        if (!enabled(ctx)) return
        val data = WidgetData.load(ctx) ?: return
        val now = Calendar.getInstance()
        val occ = data.upcoming(now).take(20)
        if (occ.isEmpty()) return

        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val ids = ArrayList<Int>()

        for (o in occ) {
            val at = o.start.timeInMillis - LEAD_MINUTES * 60_000L
            if (at <= System.currentTimeMillis() + 30_000L) continue
            val id = (o.start.timeInMillis / 60_000L).toInt()
            val i = Intent(ctx, ReminderReceiver::class.java).apply {
                action = ReminderReceiver.ACTION_CLASS
                putExtra("id", id)
                putExtra("name", o.name)
                putExtra("room", o.room)
                putExtra("time", hm(o.start))
            }
            val pi = PendingIntent.getBroadcast(
                ctx, id, i,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            runCatching { am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi) }
            ids.add(id)
        }

        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_IDS, ids.joinToString(","))
            .apply()
    }

    fun cancelAll(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_IDS, "") ?: ""
        if (raw.isBlank()) return
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        for (s in raw.split(",")) {
            val id = s.toIntOrNull() ?: continue
            val i = Intent(ctx, ReminderReceiver::class.java).setAction(ReminderReceiver.ACTION_CLASS)
            val pi = PendingIntent.getBroadcast(
                ctx, id, i,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            runCatching { am?.cancel(pi) }
        }
        prefs.edit().putString(KEY_IDS, "").apply()
    }

    // ---------------------------------------------------------------- 发通知
    fun channel(ctx: Context, id: String, name: String, importance: Int) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(id) != null) return
        nm.createNotificationChannel(
            NotificationChannel(id, name, importance).apply {
                description = if (id == CH_CLASS) "上课前提醒" else "出分提醒"
            }
        )
    }

    fun notifyClass(ctx: Context, name: String, room: String, time: String, id: Int) {
        channel(ctx, CH_CLASS, "课程提醒", NotificationManager.IMPORTANCE_HIGH)
        val body = buildString {
            append(time)
            append(" 上课")
            if (room.isNotBlank()) {
                append(" · ")
                append(room)
            }
        }
        post(ctx, id, "还有 12 分钟 · $name", body, CH_CLASS)
    }

    fun notifyGrade(ctx: Context, title: String, text: String) {
        channel(ctx, CH_GRADE, "成绩更新", NotificationManager.IMPORTANCE_DEFAULT)
        post(ctx, 7801, title, text, CH_GRADE)
    }

    private fun post(ctx: Context, id: Int, title: String, text: String, ch: String) {
        val open = PendingIntent.getActivity(
            ctx, 0,
            Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val n = Notification.Builder(ctx, ch)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_haut)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        runCatching {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(id, n)
        }
    }

    private fun hm(c: Calendar): String =
        SimpleDateFormat("HH:mm", Locale.getDefault()).format(c.time)
}

class ReminderReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_CLASS = "cn.edu.haut.hautbox.CLASS_REMIND"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_CLASS) return
        val name = intent.getStringExtra("name") ?: return
        val room = intent.getStringExtra("room") ?: ""
        val time = intent.getStringExtra("time") ?: ""
        val id = intent.getIntExtra("id", 7000)
        ClassReminder.notifyClass(context, name, room, time, id)
    }
}
