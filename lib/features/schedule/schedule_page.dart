import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../ui/glass/glass.dart';
import '../../ui/glass/picker.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  int? _week;
  bool? _showWeekend;
  int _dir = 0; // 滑动方向，给切换动画用

  int get _total => AppState.instance.schedule?.student.totalWeeks ?? 20;

  int get _currentWeek => AppState.instance.schedule?.student.currentWeek ?? 1;

  int get _weekShown => (_week ?? _currentWeek).clamp(1, math.max(_total, 1)).toInt();

  void _shiftWeek(int delta) {
    final next = (_weekShown + delta).clamp(1, _total);
    if (next == _weekShown) return;
    setState(() {
      _dir = delta;
      _week = next;
    });
  }

  Future<void> _pickWeek(BuildContext context) async {
    final picked = await showGlassPicker<int>(
      context,
      title: '选择周次',
      items: [
        GlassPickerItem(
          label: '跳转到本周',
          value: _currentWeek,
          hint: '第 $_currentWeek 周',
          selected: _weekShown == _currentWeek,
          dividerAfter: true,
        ),
        for (var w = 1; w <= _total; w++)
          GlassPickerItem(
            label: '第 $w 周',
            value: w,
            hint: w == _currentWeek ? '本周' : null,
            selected: w == _weekShown,
          ),
      ],
    );
    if (picked != null && mounted && picked != _weekShown) {
      setState(() {
        _dir = picked > _weekShown ? 1 : -1;
        _week = picked;
      });
    }
  }

  Future<void> _pickTerm(BuildContext context) async {
    final s = AppState.instance;
    if (s.terms.isEmpty) return;
    final picked = await showGlassPicker<Term>(
      context,
      title: '切换学期',
      items: [
        for (final t in s.terms)
          GlassPickerItem(
            label: t.displayLabel,
            value: t,
            hint: t.key == s.activeTerm?.key ? '当前' : null,
            selected: t.key == s.activeTerm?.key,
          ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _week = null);
      s.switchTerm(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final g = GlassTheme.of(context);
    final data = s.schedule;
    final week = _weekShown;

    final all = data?.courses ?? const <Course>[];
    final hasWeekend = all.any((c) => c.day >= 6);
    final showWeekend = _showWeekend ?? hasWeekend;
    final days = showWeekend ? 7 : 5;
    final shown = all.where((c) => c.activeIn(week) && c.day <= days).toList();

    final termLabel = data?.student.termName ?? '未登录';

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 学期（可点切）→ 标题 + 周次下拉 + 两个按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: s.terms.isEmpty ? null : () => _pickTerm(context),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          termLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: .4,
                            color: g.textTertiary,
                          ),
                        ),
                        if (s.terms.isNotEmpty) ...[
                          const SizedBox(width: 2),
                          Icon(Icons.expand_more_rounded, size: 14, color: g.textTertiary),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '课表',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          color: g.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      GlassPillButton(
                        label: '第 $week 周',
                        onTap: () => _pickWeek(context),
                      ),
                      const SizedBox(width: 7),
                      GlassIconButton(
                        icon: Icons.grid_view_rounded,
                        size: 36,
                        iconSize: 18,
                        tooltip: showWeekend ? '只看工作日' : '显示周末',
                        onTap: () => setState(() => _showWeekend = !showWeekend),
                      ),
                      const SizedBox(width: 7),
                      GlassIconButton(
                        icon: Icons.refresh_rounded,
                        size: 36,
                        iconSize: 18,
                        tooltip: '刷新',
                        onTap: () => s.refreshAll(force: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: data == null
                  ? const _Empty()
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v < -120) _shiftWeek(1);
                        if (v > 120) _shiftWeek(-1);
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) {
                          final slide = Tween<Offset>(
                            begin: Offset(_dir >= 0 ? .12 : -.12, 0),
                            end: Offset.zero,
                          ).animate(anim);
                          return ClipRect(
                            child: SlideTransition(
                              position: slide,
                              child: FadeTransition(opacity: anim, child: child),
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey('wk-$week-$days'),
                          child: _Timetable(
                            week: week,
                            days: days,
                            courses: shown,
                            termStart: _termStart(data),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 74),
              child: Text(
                _ageLine(s),
                style: TextStyle(fontSize: 10, color: g.textTertiary, letterSpacing: .2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ageLine(AppState s) {
    final age = AppState.ageText(s.scheduleAt);
    if (s.offline) return '$age · 当前离线，显示本地缓存';
    return age;
  }

  DateTime? _termStart(ScheduleData? data) {
    final raw = data?.student.termStart;
    if (raw == null) return null;
    return DateTime.tryParse(raw.replaceAll('/', '-'));
  }
}

class _Timetable extends StatelessWidget {
  const _Timetable({
    required this.week,
    required this.days,
    required this.courses,
    required this.termStart,
  });

  final int week;
  final int days;
  final List<Course> courses;
  final DateTime? termStart;

  static const double _timeColW = 24;
  static const double _bandH = 11;
  static const int _bandAfter1 = 4; // 上午结束
  static const int _bandAfter2 = 8; // 下午结束

  /// 第 p 节的顶部 y（把分段空隙算进去）
  static double _y(int period, double rowH) {
    var bands = 0;
    if (period > _bandAfter1) bands++;
    if (period > _bandAfter2) bands++;
    return (period - 1) * rowH + bands * _bandH;
  }

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final total = PeriodTimes.count;
    final layout = _layout(courses);

    return LayoutBuilder(
      builder: (context, box) {
        const headerH = 24.0;
        final avail = math.max(200.0, box.maxHeight - headerH);
        // 行高按屏幕均分：一屏装下整天，不用滚
        final rowH = ((avail - _bandH * 2) / total).clamp(29.0, 52.0);
        final dayW = (box.maxWidth - _timeColW) / days;
        final contentH = total * rowH + _bandH * 2;

        final grid = SizedBox(
          height: contentH,
          child: Stack(
            children: [
              for (var p = 1; p <= total; p++)
                Positioned(
                  left: _timeColW,
                  right: 0,
                  top: _y(p, rowH),
                  child: Container(
                    height: .5,
                    color: g.border.withValues(alpha: p == 1 ? .3 : .13),
                  ),
                ),
              // 上午 / 下午 分界
              for (final band in const [_bandAfter1, _bandAfter2])
                Positioned(
                  left: 0,
                  right: 0,
                  top: _y(band, rowH) + rowH,
                  height: _bandH,
                  child: Container(
                    color: g.isDark
                        ? Colors.white.withValues(alpha: .028)
                        : Colors.black.withValues(alpha: .022),
                    alignment: Alignment.center,
                    child: Text(
                      band == _bandAfter1 ? '上午' : '下午',
                      style: TextStyle(
                        fontSize: 7.5,
                        height: 1,
                        letterSpacing: 2,
                        color: g.textTertiary.withValues(alpha: .8),
                      ),
                    ),
                  ),
                ),
              // 时间轴：只标第几节（作息时间各学院不同，不硬编码）
              for (var p = 1; p <= total; p++)
                Positioned(
                  left: 0,
                  top: _y(p, rowH),
                  width: _timeColW - 4,
                  height: rowH,
                  child: Center(
                    child: Text(
                      '$p',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: g.textTertiary,
                      ),
                    ),
                  ),
                ),
              // 课程块
              for (final item in layout)
                Positioned(
                  left: _timeColW + 1 + (item.course.day - 1) * dayW + item.lane * (dayW / item.lanes),
                  top: _y(item.course.startPeriod, rowH) + 1.5,
                  width: (dayW / item.lanes) - 2,
                  height: _y(item.course.endPeriod, rowH) +
                      rowH -
                      _y(item.course.startPeriod, rowH) -
                      3,
                  child: _CourseCard(course: item.course),
                ),
            ],
          ),
        );

        return Column(
          children: [
            _DayHeader(days: days, week: week, termStart: termStart, timeColW: _timeColW),
            if (contentH <= avail + 1) grid else Expanded(child: SingleChildScrollView(child: grid)),
          ],
        );
      },
    );
  }

  static List<_Placed> _layout(List<Course> courses) {
    final out = <_Placed>[];
    for (var d = 1; d <= 7; d++) {
      final list = courses.where((c) => c.day == d).toList()
        ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
      final laneEnd = <int>[];
      final laneOf = <Course, int>{};
      for (final c in list) {
        var lane = laneEnd.indexWhere((end) => end < c.startPeriod);
        if (lane == -1) {
          laneEnd.add(c.endPeriod);
          lane = laneEnd.length - 1;
        } else {
          laneEnd[lane] = c.endPeriod;
        }
        laneOf[c] = lane;
      }
      final maxLanes = laneEnd.length.clamp(1, 3).toInt();
      for (final c in list) {
        var lanes = 1;
        for (final o in list) {
          if (o == c) continue;
          final overlaps = !(o.endPeriod < c.startPeriod || o.startPeriod > c.endPeriod);
          if (overlaps) lanes = math.max(lanes, maxLanes);
        }
        out.add(_Placed(c, laneOf[c]!, lanes));
      }
    }
    return out;
  }
}

class _Placed {
  const _Placed(this.course, this.lane, this.lanes);
  final Course course;
  final int lane;
  final int lanes;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.days,
    required this.week,
    required this.termStart,
    required this.timeColW,
  });

  final int days;
  final int week;
  final DateTime? termStart;
  final double timeColW;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final now = DateTime.now();
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          SizedBox(width: timeColW),
          for (var d = 1; d <= days; d++)
            Expanded(
              child: Builder(builder: (context) {
                DateTime? date;
                if (termStart != null) {
                  date = termStart!.add(Duration(days: (week - 1) * 7 + (d - 1)));
                }
                final isToday = date != null &&
                    date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '周${PeriodTimes.weekLabels[d - 1]}',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                        color: isToday ? g.accent : g.textSecondary,
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        '${date.month}/${date.day}',
                        style: TextStyle(
                          fontSize: 8.5,
                          height: 1,
                          color: isToday ? g.accent : g.textTertiary,
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  static const _palette = [
    Color(0xFF2F6BFF),
    Color(0xFF00B39B),
    Color(0xFFEF6C4D),
    Color(0xFF7A5CFF),
    Color(0xFFE0457B),
    Color(0xFF2FA36B),
    Color(0xFFE9A319),
    Color(0xFF3E8ED0),
  ];

  Color get _color => _palette[course.name.hashCode.abs() % _palette.length];

  /// "莲32号教学楼528" → "莲32-528"
  static String shortRoom(String s) {
    final m = RegExp(r'^(\D{0,4}?)(\d{1,3})\s*号?\s*教学?楼?\s*(\d{2,4})').firstMatch(s);
    if (m != null) return '${m.group(1)}${m.group(2)}-${m.group(3)}';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final c = _color;
    final tight = (course.endPeriod - course.startPeriod + 1) == 1;
    final room = course.room == null ? null : shortRoom(course.room!);

    return GestureDetector(
      onTap: () => _showDetail(context, course, c),
      child: Container(
        decoration: BoxDecoration(
          color: c.withValues(alpha: g.isDark ? .20 : .13),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: .38), width: .7),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: c.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 2.5, 2, 2.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      maxLines: tight ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.6,
                        height: 1.14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.2,
                        color: g.textPrimary,
                      ),
                    ),
                    if (room != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        room,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 7.8, height: 1.14, color: g.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Course course, Color color) {
    final g = GlassTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        child: GlassPanel(
          radius: AppTokens.rXl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: g.textTertiary.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 34,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      course.name,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.3,
                        color: g.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _kv(context, Icons.schedule_rounded,
                  '${PeriodTimes.weekFull[course.day - 1]} 第 ${course.startPeriod}-${course.endPeriod} 节',
                  null),
              if (course.room != null) _kv(context, Icons.place_outlined, course.room!, null),
              if (course.teacher != null)
                _kv(context, Icons.person_outline_rounded, course.teacher!, null),
              if (course.rawWeeks != null)
                _kv(context, Icons.event_repeat_rounded, course.rawWeeks!, null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, IconData icon, String k, String? v) {
    final g = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, size: 15, color: g.textTertiary),
          const SizedBox(width: 9),
          Expanded(child: Text(k, style: TextStyle(fontSize: 13.5, color: g.textPrimary))),
          if (v != null) Text(v, style: TextStyle(fontSize: 12.5, color: g.textSecondary)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 38, color: g.textTertiary),
            const SizedBox(height: 14),
            Text(
              '还没有课表数据',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: g.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '下拉刷新，或到「更多」里检查登录状态',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.6, color: g.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
