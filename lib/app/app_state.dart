import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/zf_auth.dart';
import '../core/cache/json_cache.dart';
import '../core/constants.dart';
import '../core/net/zf_http.dart';
import '../core/term_calendar.dart';
import '../core/widget/widget_bridge.dart';
import '../data/api/zf_api.dart';
import '../data/demo/demo_data.dart';
import '../data/models/models.dart';

/// 全局状态。不引入状态管理框架 —— 单例 + ChangeNotifier 足够，
/// 后面要换成 Riverpod 时，页面只依赖这几个读写方法，改动面很小。
///
/// 数据策略（2026-11 与用户确认）：
///   第一次启动 → 联网取；之后每次打开 → 先把缓存打到屏幕上（秒开），
///   再按 TTL 决定要不要在后台补一次。TTL 内绝不打扰服务器。
///   下拉刷新 / 切学期 / 登录后 = 强制取。
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  // ---------------- 基础设施 ----------------
  final ZfHttp http = ZfHttp();
  late final ZfApi api = ZfApi(http);
  late final ZfAuth auth = ZfAuth(http);
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SharedPreferences? _prefs;
  JsonCache? _cache;

  // ---------------- 会话 ----------------
  bool loggedIn = false;
  String? studentName;
  String? studentId;

  // ---------------- 数据 ----------------
  ScheduleData? schedule;
  List<ExamItem> exams = const [];
  List<GradeItem> grades = const [];
  List<Term> terms = const [];
  Term? activeTerm;

  /// 每个学期的成绩（切学期/看全部时不用重复请求）
  final Map<String, List<GradeItem>> gradesByTerm = {};

  // ---------------- 界面态 ----------------
  bool loading = false;
  bool gradeLoading = false;
  String? error;
  bool offline = false;

  ThemeMode themeMode = ThemeMode.dark;
  int blurTier = 2; // 0关 / 1轻 / 2标准 / 3强

  // WiFi
  String wifiSsid = '';
  String srunHost = '172.16.154.130';
  String srunPort = '69';
  String srunAcId = '1';
  bool autoAuth = true;

  /// 作息时间（可编辑），小组件倒计时用
  List<(String, String)> periods = List.of(PeriodTimes.defaults);

  String? _hydratedKey;

  bool get ready => _prefs != null;

  // ================================================================ TTL
  /// 出分季（1 月、6~7 月）成绩刷新勤一点，平时不动
  static bool get _gradeSeason {
    final m = DateTime.now().month;
    return m == 1 || m == 6 || m == 7;
  }

  static Duration ttlOf(String slot, {bool isActiveTerm = true}) {
    switch (slot) {
      case 'schedule':
        return const Duration(hours: 12);
      case 'exam':
        return const Duration(hours: 12);
      case 'terms':
        return const Duration(days: 7);
      case 'grade':
        if (!isActiveTerm) return const Duration(days: 7);
        return _gradeSeason ? const Duration(minutes: 30) : const Duration(hours: 3);
    }
    return const Duration(hours: 6);
  }

  // ================================================================ 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cache = JsonCache(_prefs!);

    themeMode = switch (_prefs!.getString('themeMode')) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    blurTier = _prefs!.getInt('blurTier') ?? 2;
    wifiSsid = _prefs!.getString('wifiSsid') ?? '';
    srunHost = _prefs!.getString('srunHost') ?? srunHost;
    srunPort = _prefs!.getString('srunPort') ?? srunPort;
    srunAcId = _prefs!.getString('srunAcId') ?? srunAcId;
    autoAuth = _prefs!.getBool('autoAuth') ?? true;
    studentName = _prefs!.getString('studentName');
    studentId = _prefs!.getString('studentId');
    periods = _loadPeriods();

    await _restoreSession();
    if (loggedIn) {
      activeTerm = _savedTerm() ?? TermCalendar.currentTerm();
      // 先把缓存打到屏幕上 —— 这一步不联网，保证秒开
      await _hydrate(activeTerm!);
      notifyListeners();
      // 再按 TTL 决定是否后台补
      unawaited(refreshAll(silent: true));
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- 作息
  List<(String, String)> _loadPeriods() {
    final raw = _prefs?.getString('periods');
    if (raw == null) return List.of(PeriodTimes.defaults);
    try {
      final list = jsonDecode(raw) as List;
      final out = <(String, String)>[];
      for (final e in list) {
        final p = e as List;
        out.add((p[0].toString(), p[1].toString()));
      }
      return out.length == PeriodTimes.count ? out : List.of(PeriodTimes.defaults);
    } catch (_) {
      return List.of(PeriodTimes.defaults);
    }
  }

  Future<void> setPeriod(int index, String start, String end) async {
    if (index < 0 || index >= periods.length) return;
    final list = List.of(periods);
    list[index] = (start, end);
    periods = list;
    await _prefs?.setString(
      'periods',
      jsonEncode(list.map((p) => [p.$1, p.$2]).toList()),
    );
    notifyListeners();
    await pushWidgetSnapshot();
  }

  // ---------------------------------------------------------------- 小组件快照
  /// 把课表压成一份 JSON 快照给原生小组件，避免组件自己联网或起 Flutter
  Future<void> pushWidgetSnapshot() async {
    final d = schedule;
    final t = activeTerm;
    if (d == null || t == null) return;
    final start = TermCalendar.startOf(t).$1;
    final payload = {
      'student': d.student.name ?? '',
      'term': d.student.termName ?? t.displayLabel,
      'termStart': _ymd(start),
      'periods': periods.map((p) => [p.$1, p.$2]).toList(),
      'courses': [
        for (final c in d.courses)
          {
            'n': c.name,
            'r': _shortRoom(c.room),
            'd': c.day,
            's': c.startPeriod,
            'e': c.endPeriod,
            'w': (c.weeks.toList()..sort()),
          }
      ],
    };
    await WidgetBridge.pushSnapshot(jsonEncode(payload));
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// "莲32号教学楼528" → "莲32-528"，桌面组件里放得下
  static String _shortRoom(String? room) {
    if (room == null || room.isEmpty) return '';
    final m = RegExp(r'^(\D{0,4}?)(\d{1,3})\s*号?\s*教学?楼?\s*(\d{2,4})').firstMatch(room);
    if (m != null) return '${m.group(1)}${m.group(2)}-${m.group(3)}';
    return room;
  }

  Term? _savedTerm() {
    final raw = _prefs?.getString('activeTerm');
    if (raw == null) return null;
    final p = raw.split('-');
    if (p.length != 2) return null;
    return Term(xnm: p[0], xqm: p[1], label: '');
  }

  Future<void> _restoreSession() async {
    try {
      final raw = await _secure.read(key: 'zf_cookies');
      if (raw == null) return;
      final map = (jsonDecode(raw) as Map).cast<String, String>();
      if (map.isEmpty) return;
      http.restoreCookies(map);
      loggedIn = true;
    } catch (_) {
      loggedIn = false;
    }
  }

  Future<void> _persistSession() async {
    await _secure.write(key: 'zf_cookies', value: jsonEncode(http.cookies));
  }

  // ================================================================ 登录
  Future<bool> login(String username, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await auth.login(username, password);
      loggedIn = true;
      studentId = username;
      await _persistSession();
      await _prefs?.setString('studentId', username);
      // 换了账号，旧缓存全清
      await _clearAllCache();
      _hydratedKey = null;
      activeTerm = TermCalendar.currentTerm();
      await refreshAll(force: true);
      return true;
    } on ZfException catch (e) {
      error = e.message;
      loggedIn = false;
      return false;
    } catch (e) {
      error = '登录出错：$e';
      loggedIn = false;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await auth.logout();
    await _secure.delete(key: 'zf_cookies');
    await _clearAllCache();
    loggedIn = false;
    schedule = null;
    exams = const [];
    grades = const [];
    gradesByTerm.clear();
    terms = const [];
    activeTerm = null;
    _hydratedKey = null;
    error = null;
    notifyListeners();
  }

  Future<void> _clearAllCache() async {
    final keys = _prefs?.getKeys().where((k) => k.startsWith('jc::')).toList() ?? const [];
    for (final k in keys) {
      await _prefs?.remove(k);
    }
    for (final s in ['schedule', 'exam', 'grade', 'terms']) {
      await _cache?.clearSlot(s);
    }
  }

  // ================================================================ 缓存 → 内存
  Future<void> _hydrate(Term t) async {
    if (_hydratedKey == t.key) return;
    final c = _cache;
    if (c == null) return;

    final sch = c.get('schedule', t.key);
    if (sch != null) {
      try {
        _applySchedule(ZfApi.parseSchedule(sch.raw, xnm: t.xnm, xqm: t.xqm), t);
      } catch (_) {}
    }
    final ex = c.get('exam', t.key);
    if (ex != null) {
      try {
        exams = ZfApi.parseExams(ex.raw)..sort(_byExamTime);
      } catch (_) {}
    }
    final gr = c.get('grade', t.key);
    if (gr != null) {
      try {
        final list = ZfApi.parseGrades(gr.raw, xqm: t.xqm);
        gradesByTerm[t.key] = list;
        grades = list;
      } catch (_) {}
    }
    _loadTermsCache();
    _hydratedKey = t.key;
  }

  void _loadTermsCache() {
    final c = _cache?.get('terms', 'all');
    if (c == null) return;
    try {
      final list = (jsonDecode(c.raw) as List)
          .map((e) => Term.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      if (list.isNotEmpty) terms = list;
    } catch (_) {}
  }

  void _applySchedule(ScheduleData d, Term t) {
    final week = TermCalendar.weekOf(t);
    final (start, totalWeeks) = TermCalendar.startOf(t);
    schedule = ScheduleData(
      student: d.student.copyWith(
        currentWeek: week,
        totalWeeks: totalWeeks,
        termName: t.displayLabel,
        termStart: start.toIso8601String(),
      ),
      courses: d.courses,
      term: t,
    );
    studentName = schedule!.student.name ?? studentName;
    _prefs?.setString('studentName', studentName ?? '');
    // 课表一变就把快照推给桌面组件
    unawaited(pushWidgetSnapshot());
  }

  static int _byExamTime(ExamItem a, ExamItem b) {
    final x = a.startAt;
    final y = b.startAt;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }

  // ================================================================ 拉数据
  Future<void> refreshAll({bool force = false, bool silent = false, Term? term}) async {
    if (!loggedIn || _cache == null) return;
    final t = term ?? activeTerm ?? TermCalendar.currentTerm();
    activeTerm = t;
    await _prefs?.setString('activeTerm', t.key);

    // 切学期后先把该学期的缓存灌进内存
    if (_hydratedKey != t.key) {
      _hydratedKey = null;
      await _hydrate(t);
      notifyListeners();
    }

    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }

    var anyError = false;

    // ---- 课表
    if (force || !_cache!.isFresh('schedule', t.key, ttlOf('schedule'))) {
      try {
        final r = await api.fetchSchedule(xnm: t.xnm, xqm: t.xqm);
        await _cache!.put('schedule', t.key, r.raw);
        _applySchedule(r.data, t);
        anyError = false;
      } on ZfException catch (e) {
        _noteError(e);
        anyError = true;
      } catch (e) {
        error = '课表加载失败：$e';
        anyError = true;
      }
    }

    // ---- 学期列表
    if (force || terms.isEmpty || !_cache!.isFresh('terms', 'all', ttlOf('terms'))) {
      try {
        final list = await api.fetchTerms();
        if (list.isNotEmpty) {
          terms = list;
          await _cache!.put('terms', 'all', jsonEncode(list.map((e) => e.toJson()).toList()));
        }
      } catch (_) {}
    }

    // ---- 考试
    if (force || !_cache!.isFresh('exam', t.key, ttlOf('exam'))) {
      try {
        final r = await api.fetchExams(xnm: t.xnm, xqm: t.xqm);
        await _cache!.put('exam', t.key, r.raw);
        exams = r.data..sort(_byExamTime);
      } catch (e) {
        if (e is ZfException && e.code == 'session') _noteError(e);
      }
    }

    // ---- 成绩（当前学期）
    if (force || !_cache!.isFresh('grade', t.key, ttlOf('grade'))) {
      await loadGrades(t, force: true, quiet: true);
    }

    offline = anyError && schedule != null;
    loading = false;
    notifyListeners();
  }

  void _noteError(ZfException e) {
    error = e.message;
    if (e.code == 'session') {
      loggedIn = false;
      _secure.delete(key: 'zf_cookies');
    }
  }

  // ================================================================ 成绩（按学期）
  Future<void> loadGrades(Term t, {bool force = false, bool quiet = false}) async {
    _cache ??= JsonCache(_prefs!);
    final isActive = t.key == activeTerm?.key;
    final ttl = ttlOf('grade', isActiveTerm: isActive);

    if (!force && _cache!.isFresh('grade', t.key, ttl)) {
      final c = _cache!.get('grade', t.key);
      if (c != null) {
        try {
          _setGrades(t, ZfApi.parseGrades(c.raw, xqm: t.xqm));
          return;
        } catch (_) {}
      }
    }

    if (!quiet) {
      gradeLoading = true;
      notifyListeners();
    }
    try {
      final r = await api.fetchGrades(xnm: t.xnm, xqm: t.xqm);
      await _cache!.put('grade', t.key, r.raw);
      _setGrades(t, r.data);
    } on ZfException catch (e) {
      // 网络挂了：有缓存就用缓存，别把已有内容清空
      final c = _cache!.get('grade', t.key);
      if (c != null) {
        try {
          _setGrades(t, ZfApi.parseGrades(c.raw, xqm: t.xqm));
        } catch (_) {}
      } else if (e.code == 'session') {
        _noteError(e);
      }
    } catch (_) {
      // 忽略：保持现有数据
    } finally {
      if (!quiet) {
        gradeLoading = false;
        notifyListeners();
      }
    }
  }

  void _setGrades(Term t, List<GradeItem> list) {
    gradesByTerm[t.key] = list;
    if (t.key == activeTerm?.key) grades = list;
  }

  /// 可选学期：当前学期 + 往年（按学年倒序，最多 8 个）
  List<Term> get gradeTermOptions {
    final all = terms.isEmpty ? [if (activeTerm != null) activeTerm!] : terms;
    final year = int.tryParse(schedule?.student.grade ?? '') ?? 2024;
    final filtered = all
        .where((t) => (int.tryParse(t.xnm) ?? 0) >= year - 1)
        .toList()
      ..sort((a, b) {
        final c = b.xnm.compareTo(a.xnm);
        return c != 0 ? c : b.xqm.compareTo(a.xqm);
      });
    return filtered.take(8).toList();
  }

  /// 把所有学期的成绩都拉一遍（缓存命中的不请求）
  Future<void> loadAllGrades() async {
    for (final t in gradeTermOptions) {
      if (!_cache!.isFresh('grade', t.key, ttlOf('grade', isActiveTerm: t.key == activeTerm?.key))) {
        await loadGrades(t);
      }
    }
    notifyListeners();
  }

  /// 合并某一批学期的成绩（"全部"视图用）
  List<GradeItem> gradesOf(Iterable<Term> list) {
    final out = <GradeItem>[];
    for (final t in list) {
      final g = gradesByTerm[t.key];
      if (g == null) continue;
      out.addAll(g);
    }
    return out;
  }

  // ================================================================ 时间戳文案
  DateTime? get scheduleAt =>
      activeTerm == null ? null : _cache?.get('schedule', activeTerm!.key)?.at;

  DateTime? get gradeAt =>
      activeTerm == null ? null : _cache?.get('grade', activeTerm!.key)?.at;

  DateTime? gradeAtOf(Term t) => _cache?.get('grade', t.key)?.at;

  DateTime? get examAt =>
      activeTerm == null ? null : _cache?.get('exam', activeTerm!.key)?.at;

  /// "数据截至 今天 09:34" / "昨天 21:10" / "11-23 08:00"
  static String ageText(DateTime? at) {
    if (at == null) return '尚未同步';
    final now = DateTime.now();
    final d = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final hm = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final diff = today.difference(d).inDays;
    if (diff == 0) return '数据截至 今天 $hm';
    if (diff == 1) return '数据截至 昨天 $hm';
    return '数据截至 ${at.month}-${at.day} $hm';
  }

  // ================================================================ 演示数据
  void loadDemo() {
    final d = DemoData.schedule();
    schedule = d;
    exams = DemoData.exams();
    grades = DemoData.grades();
    gradesByTerm[d.term!.key] = grades;
    terms = DemoData.terms;
    activeTerm = d.term;
    studentName = d.student.name;
    offline = false;
    error = null;
    _hydratedKey = d.term!.key;
    notifyListeners();
  }

  // ================================================================ 偏好
  Future<void> switchTerm(Term t) async {
    activeTerm = t;
    _hydratedKey = null;
    loading = true;
    notifyListeners();
    await refreshAll(term: t, force: true);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _prefs?.setString('themeMode', m.name);
    notifyListeners();
  }

  Future<void> setBlurTier(int t) async {
    blurTier = t;
    await _prefs?.setInt('blurTier', t);
    notifyListeners();
  }

  Future<void> setWifi({
    String? ssid,
    String? host,
    String? port,
    String? acId,
    bool? auto,
  }) async {
    if (ssid != null) {
      wifiSsid = ssid;
      await _prefs?.setString('wifiSsid', ssid);
    }
    if (host != null) {
      srunHost = host;
      await _prefs?.setString('srunHost', host);
    }
    if (port != null) {
      srunPort = port;
      await _prefs?.setString('srunPort', port);
    }
    if (acId != null) {
      srunAcId = acId;
      await _prefs?.setString('srunAcId', acId);
    }
    if (auto != null) {
      autoAuth = auto;
      await _prefs?.setBool('autoAuth', auto);
    }
    notifyListeners();
  }
}
