package cn.edu.haut.hautbox.widget

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * 小组件的数据源：只读 Flutter 写好的「日程快照」，不联网、不启动 Flutter。
 *
 * 快照结构（由 dart 侧 lib/core/widget/widget_bridge.dart 生成）：
 * {
 *   "student": "张同学",
 *   "term": "2026-2027 第一学期",
 *   "termStart": "2026-08-31",        // 第 1 周周一
 *   "periods": [["08:30","09:15"], ...],
 *   "courses": [{"n":"数据结构","r":"莲4-214","d":1,"s":3,"e":4,"w":[1,2,...]}]
 * }
 */
class WidgetData private constructor(
    val student: String,
    val term: String,
    val termStart: Calendar,
    val periods: List<Pair<String, String>>,
    val courses: List<Course>,
) {

    data class Course(
        val name: String,
        val room: String,
        val day: Int,      // 1=周一
        val start: Int,    // 第几节开始
        val end: Int,      // 第几节结束
        val weeks: Set<Int>,
    )

    data class Occ(
        val name: String,
        val room: String,
        val start: Calendar,
        val end: Calendar,
        val dayOffset: Int,
    ) {
        fun minutesTo(c: Calendar): Int =
            ((start.timeInMillis - c.timeInMillis) / 60000L).toInt()

        fun remainMinutes(c: Calendar): Int =
            ((end.timeInMillis - c.timeInMillis) / 60000L).toInt()
    }

    // ---------------------------------------------------------------- 计算
    fun weekOf(day: Calendar): Int {
        val a = atMidnight(termStart)
        val b = atMidnight(day)
        val days = ((b.timeInMillis - a.timeInMillis) / 86400000L).toInt()
        if (days < 0) return 0
        return days / 7 + 1
    }

    /** 未来 7 天内所有课（按时间排好） */
    fun upcoming(now: Calendar): List<Occ> {
        val out = ArrayList<Occ>()
        val base = atMidnight(now)
        for (offset in 0..7) {
            val day = (base.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, offset) }
            val week = weekOf(day)
            if (week <= 0 || week > 30) continue
            val weekday = day.get(Calendar.DAY_OF_WEEK).let { if (it == Calendar.SUNDAY) 7 else it - 1 }
            for (c in courses) {
                if (c.day != weekday) continue
                if (c.weeks.isNotEmpty() && !c.weeks.contains(week)) continue
                val s = timeAt(day, c.start, first = true) ?: continue
                val e = timeAt(day, c.end, first = false) ?: continue
                if (e.timeInMillis <= now.timeInMillis) continue
                out.add(Occ(c.name, c.room, s, e, offset))
            }
        }
        out.sortBy { it.start.timeInMillis }
        return out
    }

    /** 今天的课（全部，含已上完的） */
    fun today(now: Calendar): List<Occ> {
        val base = atMidnight(now)
        val week = weekOf(base)
        if (week <= 0) return emptyList()
        val weekday = base.get(Calendar.DAY_OF_WEEK).let { if (it == Calendar.SUNDAY) 7 else it - 1 }
        return courses
            .filter { it.day == weekday && (it.weeks.isEmpty() || it.weeks.contains(week)) }
            .sortedBy { it.start }
            .mapNotNull { c ->
                val s = timeAt(base, c.start, true) ?: return@mapNotNull null
                val e = timeAt(base, c.end, false) ?: return@mapNotNull null
                Occ(c.name, c.room, s, e, 0)
            }
    }

    private fun timeAt(day: Calendar, period: Int, first: Boolean): Calendar? {
        val idx = period - 1
        if (idx < 0 || idx >= periods.size) return null
        val hm = if (first) periods[idx].first else periods[idx].second
        val parts = hm.split(":")
        if (parts.size != 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        return (day.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, h)
            set(Calendar.MINUTE, m)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }

    companion object {
        private const val PREFS = "haut_widget"
        private const val KEY = "snapshot"

        fun atMidnight(c: Calendar): Calendar = (c.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        fun load(ctx: Context): WidgetData? {
            val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
                ?: return null
            return runCatching { parse(raw) }.getOrNull()
        }

        fun save(ctx: Context, raw: String) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, raw).apply()
        }

        private fun parse(raw: String): WidgetData {
            val o = JSONObject(raw)
            val startStr = o.optString("termStart", "")
            val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val termStart = Calendar.getInstance().apply {
                val parsed = runCatching { fmt.parse(startStr) }.getOrNull()
                if (parsed != null) {
                    time = parsed
                } else {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                }
            }

            val periods = ArrayList<Pair<String, String>>()
            val pa: JSONArray = o.optJSONArray("periods") ?: JSONArray()
            for (i in 0 until pa.length()) {
                val p = pa.optJSONArray(i) ?: continue
                periods.add(p.optString(0, "08:00") to p.optString(1, "08:45"))
            }

            val courses = ArrayList<Course>()
            val ca: JSONArray = o.optJSONArray("courses") ?: JSONArray()
            for (i in 0 until ca.length()) {
                val c = ca.optJSONObject(i) ?: continue
                val weeks = HashSet<Int>()
                val wa = c.optJSONArray("w")
                if (wa != null) for (k in 0 until wa.length()) weeks.add(wa.optInt(k))
                courses.add(
                    Course(
                        name = c.optString("n", ""),
                        room = c.optString("r", ""),
                        day = c.optInt("d", 1),
                        start = c.optInt("s", 1),
                        end = c.optInt("e", 1),
                        weeks = weeks,
                    )
                )
            }

            return WidgetData(
                student = o.optString("student", ""),
                term = o.optString("term", ""),
                termStart = termStart,
                periods = if (periods.isEmpty()) DEFAULT_PERIODS else periods,
                courses = courses,
            )
        }

        /** 河南工业大学常用作息（用户可在「更多 → 作息时间」里改） */
        val DEFAULT_PERIODS: List<Pair<String, String>> = listOf(
            "08:30" to "09:15",
            "09:20" to "10:05",
            "10:25" to "11:10",
            "11:15" to "12:00",
            "14:30" to "15:15",
            "15:20" to "16:05",
            "16:25" to "17:10",
            "17:15" to "18:00",
            "19:00" to "19:45",
            "19:50" to "20:35",
            "20:40" to "21:25",
            "21:30" to "22:15",
        )
    }
}
