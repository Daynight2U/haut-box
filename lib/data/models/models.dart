/// 教务数据模型。
///
/// 全部"宽松解析"：正方字段名在各版本间会变，取不到就给默认值，绝不让页面崩。
library;

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String? pick(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = _str(m[k]);
    if (v != null) return v;
  }
  return null;
}

double? pickNum(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    if (v is num) return v.toDouble();
    final d = double.tryParse(v.toString().trim());
    if (d != null) return d;
  }
  return null;
}

/// 学期标识。正方：xqm 3=第一学期, 12=第二学期, 16=第三学期
class Term {
  const Term({required this.xnm, required this.xqm, required this.label});

  final String xnm;
  final String xqm;
  final String label;

  /// 缓存键用 "2026-3"
  String get key => '$xnm-$xqm';

  bool get isCurrent => DateTime.now().year >= (int.tryParse(xnm) ?? 0);

  /// "2026-2027 第一学期"
  String get displayLabel {
    final y = int.tryParse(xnm);
    if (y == null) return label.isEmpty ? Term.termName(xqm) : label;
    return '${y}-${y + 1} ${Term.termName(xqm)}';
  }

  Map<String, String> toJson() => {'xnm': xnm, 'xqm': xqm, 'label': label};

  static Term fromJson(Map<String, dynamic> j) => Term(
        xnm: j['xnm'] as String? ?? '',
        xqm: j['xqm'] as String? ?? '',
        label: j['label'] as String? ?? '',
      );

  static String termName(String xqm) => switch (xqm) {
        '3' => '第一学期',
        '12' => '第二学期',
        '16' => '第三学期',
        _ => '第$xqm学期',
      };
}

class StudentInfo {
  const StudentInfo({
    this.name,
    this.id,
    this.grade,
    this.major,
    this.className,
    this.currentWeek,
    this.termName,
    this.termStart,
    this.termEnd,
    this.totalWeeks,
  });

  final String? name;
  final String? id;
  final String? grade;
  final String? major;
  final String? className;
  final int? currentWeek;
  final String? termName;
  final String? termStart;
  final String? termEnd;
  final int? totalWeeks;

  StudentInfo copyWith({
    String? name,
    String? id,
    String? grade,
    String? major,
    String? className,
    int? currentWeek,
    String? termName,
    String? termStart,
    String? termEnd,
    int? totalWeeks,
  }) {
    return StudentInfo(
      name: name ?? this.name,
      id: id ?? this.id,
      grade: grade ?? this.grade,
      major: major ?? this.major,
      className: className ?? this.className,
      currentWeek: currentWeek ?? this.currentWeek,
      termName: termName ?? this.termName,
      termStart: termStart ?? this.termStart,
      termEnd: termEnd ?? this.termEnd,
      totalWeeks: totalWeeks ?? this.totalWeeks,
    );
  }

  static StudentInfo fromXsxx(Map<String, dynamic> xs) {
    int? week = int.tryParse(pick(xs, ['DQZ', 'dqz', 'ZC']) ?? '');
    final start = pick(xs, ['XQKSSJ1', 'xqkssj1']);
    final end = pick(xs, ['XQJSSJ1', 'xqjssj1']);
    int? total;
    if (start != null && end != null) {
      final s = DateTime.tryParse(start.replaceAll('/', '-'));
      final e = DateTime.tryParse(end.replaceAll('/', '-'));
      if (s != null && e != null) {
        total = (e.difference(s).inDays / 7).ceil();
        week ??= (DateTime.now().difference(s).inDays / 7).floor() + 1;
      }
    }
    return StudentInfo(
      name: pick(xs, ['XM', 'xm']),
      id: pick(xs, ['XH_ID', 'XH', 'xh']),
      grade: pick(xs, ['NJDM_DISPLAY', 'NJDM_ID', 'NJDM', 'njmc']),
      major: pick(xs, ['ZYMCC', 'ZYMC', 'zymc']),
      className: pick(xs, ['BH_ID', 'BJMC', 'bj']),
      currentWeek: (week != null && week > 0 && week < 40) ? week : null,
      termName: pick(xs, ['XQMMC', 'xqmmc']),
      termStart: start,
      termEnd: end,
      totalWeeks: total,
    );
  }
}

class Course {
  const Course({
    required this.name,
    this.courseCode,
    this.teacher,
    this.room,
    required this.day,
    required this.startPeriod,
    required this.endPeriod,
    required this.weeks,
    this.rawWeeks,
  });

  final String name;
  final String? courseCode;
  final String? teacher;
  final String? room;
  /// 1=周一 … 7=周日
  final int day;
  final int startPeriod;
  final int endPeriod;
  final Set<int> weeks;
  final String? rawWeeks;

  bool activeIn(int week) => weeks.isEmpty || weeks.contains(week);

  /// 解析 "1-16周" / "1-8周(单)" / "3,5,7周" / "1-15周(双)"
  static Set<int> parseWeeks(String? raw) {
    if (raw == null || raw.isEmpty) return <int>{};
    final text = raw.replaceAll('周', '').replaceAll(' ', '');
    final oddOnly = text.contains('单') || raw.contains('单');
    final evenOnly = text.contains('双') || raw.contains('双');
    final out = <int>{};
    for (final seg in text.split(RegExp(r'[,，、]'))) {
      final clean = seg.replaceAll(RegExp(r'[^0-9\-]'), '');
      if (clean.isEmpty) continue;
      if (clean.contains('-')) {
        final p = clean.split('-');
        final a = int.tryParse(p[0]);
        final b = int.tryParse(p.length > 1 ? p[1] : p[0]);
        if (a == null || b == null) continue;
        for (var i = a; i <= b && i - a < 30; i++) {
          if (oddOnly && i.isEven) continue;
          if (evenOnly && i.isOdd) continue;
          out.add(i);
        }
      } else {
        final a = int.tryParse(clean);
        if (a == null) continue;
        if (oddOnly && a.isEven) continue;
        if (evenOnly && a.isOdd) continue;
        out.add(a);
      }
    }
    return out;
  }

  /// 解析节次 "1-2" / "3" / "05-06"
  static (int, int) parsePeriods(String? jcs, String? jcor) {
    final src = (jcs ?? jcor ?? '1-2').replaceAll('节', '');
    final p = src.split('-');
    final a = int.tryParse(p.first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final b = p.length > 1 ? (int.tryParse(p[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? a) : a;
    return (a, b < a ? a : b);
  }

  static Course? fromKb(Map<String, dynamic> m) {
    final name = pick(m, ['kcmc', 'KCBM_DISPLAY', 'kcbm']);
    if (name == null) return null;
    final day = int.tryParse(pick(m, ['xqj', 'XQJ']) ?? '') ??
        switch (pick(m, ['xqjmc', 'XQJMC']) ?? '') {
          '星期一' => 1,
          '星期二' => 2,
          '星期三' => 3,
          '星期四' => 4,
          '星期五' => 5,
          '星期六' => 6,
          '星期日' => 7,
          _ => 1,
        };
    final (s, e) = parsePeriods(pick(m, ['jcs', 'jc']), pick(m, ['jcor']));
    return Course(
      name: name,
      courseCode: pick(m, ['kch', 'kch_id']),
      teacher: pick(m, ['xm', 'jsxm']),
      room: pick(m, ['cdmc', 'jxdd', 'cdmc_id']),
      day: day.clamp(1, 7),
      startPeriod: s,
      endPeriod: e,
      weeks: parseWeeks(pick(m, ['zcd', 'zcmc', 'xqjmc'])),
      rawWeeks: pick(m, ['zcd', 'zcmc']),
    );
  }
}

class ScheduleData {
  const ScheduleData({required this.student, required this.courses, this.term});

  final StudentInfo student;
  final List<Course> courses;
  final Term? term;

  List<Course> get coursesNow {
    final w = student.currentWeek;
    if (w == null) return courses;
    return courses.where((c) => c.activeIn(w)).toList();
  }
}

class ExamItem {
  const ExamItem({
    required this.name,
    this.time,
    this.room,
    this.seat,
    this.mode,
    this.startAt,
  });

  final String name;
  final String? time;
  final String? room;
  final String? seat;
  final String? mode;
  final DateTime? startAt;

  static ExamItem fromJson(Map<String, dynamic> m) {
    final t = pick(m, ['kssj', 'ksrq', 'kssjms', 'KSSJ']);
    DateTime? dt;
    if (t != null) {
      // 实测格式："2026-12-15(16:20-18:20)"；也兼容 "2026-12-15 16:20"
      final d = RegExp(r'(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})').firstMatch(t);
      if (d != null) {
        final tm = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(t);
        dt = DateTime.tryParse(
          '${d.group(1)}-${d.group(2)!.padLeft(2, '0')}-${d.group(3)!.padLeft(2, '0')} '
          '${(tm?.group(1) ?? '0').padLeft(2, '0')}:${tm?.group(2) ?? '00'}:00',
        );
      }
    }
    return ExamItem(
      name: pick(m, ['kcmc', 'kcmc_display', 'kc']) ?? '未知考试',
      time: t,
      room: pick(m, ['cdmc', 'kscd', 'jxdd', 'JXDD']),
      seat: pick(m, ['zwh', 'cwh', 'seat']),
      mode: pick(m, ['ksfs', 'ksfsmc', 'khfs', 'ksxz']),
      startAt: dt,
    );
  }
}

class GradeItem {
  const GradeItem({
    required this.name,
    this.score,
    this.credit,
    this.gpa,
    this.nature,
    this.term,
    this.isPass,
  });

  final String name;
  final String? score;
  final double? credit;
  final double? gpa;
  final String? nature;
  final String? term;
  final bool? isPass;

  static GradeItem fromJson(Map<String, dynamic> m, {String? term}) {
    final score = pick(m, ['cj', 'zf', 'cjjd']);
    final pass = switch (score) {
      null => null,
      '通过' || '合格' || '优秀' || '良好' || '中等' || '及格' => true,
      '不通过' || '不合格' || '不及格' => false,
      _ => double.tryParse(score) != null ? (double.parse(score) >= 60) : null,
    };
    return GradeItem(
      name: pick(m, ['kcmc', 'kcbm_display']) ?? '未知课程',
      score: score,
      credit: pickNum(m, ['xf', 'xs']),
      gpa: pickNum(m, ['jd', 'zfjd']),
      nature: pick(m, ['kcxzmc', 'kcxz', 'kclbmc']),
      term: term,
      isPass: pass,
    );
  }

  double get creditValue => credit ?? 0;
}

class GradeSummary {
  const GradeSummary({
    required this.items,
    required this.gpa,
    required this.credits,
    required this.count,
  });

  final List<GradeItem> items;
  final double gpa;
  final double credits;
  final int count;

  static GradeSummary of(List<GradeItem> list) {
    var creditSum = 0.0;
    var weighted = 0.0;
    for (final g in list) {
      if (g.credit == null || g.gpa == null) continue;
      creditSum += g.credit!;
      weighted += g.credit! * g.gpa!;
    }
    final totalCredit = list.fold<double>(0, (a, b) => a + b.creditValue);
    return GradeSummary(
      items: list,
      gpa: creditSum == 0 ? 0 : weighted / creditSum,
      credits: totalCredit,
      count: list.length,
    );
  }
}
