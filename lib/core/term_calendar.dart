import '../data/models/models.dart';

/// 学期日历：正方不返回"当前第几周"，只能靠校历算。
///
/// 数据来源：河南工业大学教务处 2026-2027 学年第 1 学期校历
/// （在校生正式上课 2026-08-31，共 20 周，期末考试 2027-01-11~01-15）。
/// 未知学期按"第一学期 9 月第一个周一 / 第二学期 3 月第一个周一"兜底，
/// 用户也可以在「更多 → 学期设置」里手动指定开学日期。
class TermCalendar {
  TermCalendar._();

  /// key = "$xnm-$xqm"（DateTime 不是 const，所以用 final）
  static final Map<String, (DateTime, int)> _known = {
    '2026-3': (DateTime(2026, 8, 31), 20),
    '2025-12': (DateTime(2026, 3, 2), 20),
    '2025-3': (DateTime(2025, 9, 1), 20),
    '2024-12': (DateTime(2025, 2, 24), 20),
    '2024-3': (DateTime(2024, 9, 2), 20),
  };

  static DateTime _mondayOnOrAfter(DateTime d) {
    final delta = (DateTime.monday - d.weekday) % 7;
    return DateTime(d.year, d.month, d.day).add(Duration(days: delta));
  }

  /// 开学第一周的周一 + 总周数
  static (DateTime, int) startOf(Term term, {DateTime? override}) {
    if (override != null) return (override, 20);
    final hit = _known['${term.xnm}-${term.xqm}'];
    if (hit != null) return hit;
    final year = int.tryParse(term.xnm) ?? DateTime.now().year;
    if (term.xqm == '12') {
      return (_mondayOnOrAfter(DateTime(year + 1, 3, 1)), 20);
    }
    return (_mondayOnOrAfter(DateTime(year, 9, 1)), 20);
  }

  /// 今天在第几周（1 起）。超出范围返回 null，交给界面决定显示什么。
  static int? weekOf(Term term, {DateTime? now, DateTime? override}) {
    final (start, _) = startOf(term, override: override);
    final today = now ?? DateTime.now();
    final days = DateTime(today.year, today.month, today.day).difference(start).inDays;
    if (days < 0) return null;
    final week = days ~/ 7 + 1;
    return week;
  }

  /// 本地推算"当前学期"。8 月起算新学年第一学期，2~7 月算第二学期。
  static Term currentTerm([DateTime? now]) {
    final n = now ?? DateTime.now();
    if (n.month >= 8) {
      return Term(xnm: '${n.year}', xqm: '3', label: '${n.year}-${n.year + 1} 第一学期');
    }
    if (n.month <= 1) {
      return Term(xnm: '${n.year - 1}', xqm: '3', label: '${n.year - 1}-${n.year} 第一学期');
    }
    return Term(xnm: '${n.year - 1}', xqm: '12', label: '${n.year - 1}-${n.year} 第二学期');
  }
}
