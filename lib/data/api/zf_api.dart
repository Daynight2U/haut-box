import 'dart:convert';

import '../../core/net/zf_http.dart';
import '../models/models.dart';

/// 接口返回值 + 原始报文。
/// 原始报文一定要带出来：① 落本地做离线兜底 ② 学校改字段时能直接看原文排查。
class ApiResult<T> {
  const ApiResult(this.data, this.raw);
  final T data;
  final String raw;
}

/// 正方教务数据接口层
///
/// 约定：这一层只负责"发请求 + 拿到原始 JSON + 宽松转模型"，
/// 缓存、降级、UI 状态都在 Repository 里。学校改接口时只需要动这里。
class ZfApi {
  ZfApi(this.http);

  final ZfHttp http;

  // ---------------------------------------------------------------- 课表
  Future<ApiResult<ScheduleData>> fetchSchedule({String xnm = '', String xqm = ''}) async {
    final r = await http.postForm(
      '/kbcx/xskbcx_cxXsKb.html',
      {'xnm': xnm, 'xqm': xqm, 'kzlx': 'ck'},
      query: {'gnmkdm': 'N2151'},
    );
    if (!r.isJson) {
      throw ZfException('课表接口返回的不是 JSON（多半是会话失效被踢回登录页）', code: 'session');
    }
    return ApiResult(parseSchedule(r.body), r.body);
  }

  static ScheduleData parseSchedule(String raw, {String xnm = '', String xqm = ''}) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final xsxx = (j['xsxx'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final kb = (j['kbList'] as List?) ?? const [];
    final courses = <Course>[];
    for (final e in kb) {
      if (e is Map) {
        final c = Course.fromKb(e.cast<String, dynamic>());
        if (c != null) courses.add(c);
      }
    }
    return ScheduleData(
      student: StudentInfo.fromXsxx(xsxx),
      courses: courses,
      term: Term(xnm: xnm, xqm: xqm, label: xsxx['XQMMC']?.toString() ?? ''),
    );
  }

  // ---------------------------------------------------------------- 考试
  Future<ApiResult<List<ExamItem>>> fetchExams({String xnm = '', String xqm = ''}) async {
    final r = await http.postForm(
      '/kwgl/kscx_cxXsksxxIndex.html',
      {
        'xnm': xnm,
        'xqm': xqm,
        'ksmcdmb_id': '',
        'kc': '',
        'ksrq': '',
        'kkbm_id': '',
        '_search': 'false',
        'nd': _ms(),
        'queryModel.showCount': '100',
        'queryModel.currentPage': '1',
        'queryModel.sortName': '',
        'queryModel.sortOrder': 'asc',
      },
      query: {'doType': 'query', 'gnmkdm': 'N358105'},
    );
    if (!r.isJson) throw ZfException('考试接口返回异常', code: 'session');
    return ApiResult(parseExams(r.body), r.body);
  }

  static List<ExamItem> parseExams(String raw) {
    final j = jsonDecode(raw);
    final items = (j is Map ? j['items'] as List? : j as List?) ?? const [];
    return [
      for (final e in items)
        if (e is Map) ExamItem.fromJson(e.cast<String, dynamic>()),
    ];
  }

  // ---------------------------------------------------------------- 成绩
  //
  // 注意：HAUT 部署里 /cjcx/cjcx_cxXsgrcj.html 是 404「系统维护页面」，
  // 真正能用的是成绩总览页 cjcx_cxDgXscj.html 的 jqGrid 数据接口（doType=query）。
  Future<ApiResult<List<GradeItem>>> fetchGrades({String xnm = '', String xqm = ''}) async {
    final r = await http.postForm(
      '/cjcx/cjcx_cxDgXscj.html',
      {
        'xnm': xnm,
        'xqm': xqm,
        '_search': 'false',
        'nd': _ms(),
        'queryModel.showCount': '200',
        'queryModel.currentPage': '1',
        'queryModel.sortName': '',
        'queryModel.sortOrder': 'asc',
        'sfzcjx': '0',
      },
      query: {'doType': 'query', 'gnmkdm': 'N305005'},
    );
    if (!r.isJson) throw ZfException('成绩接口返回异常', code: 'session');
    return ApiResult(parseGrades(r.body, xqm: xqm), r.body);
  }

  static List<GradeItem> parseGrades(String raw, {String xqm = ''}) {
    final j = jsonDecode(raw);
    final items = (j is Map ? j['items'] as List? : j as List?) ?? const [];
    final label = Term.termName(xqm);
    return [
      for (final e in items)
        if (e is Map) GradeItem.fromJson(e.cast<String, dynamic>(), term: label),
    ];
  }

  // ---------------------------------------------------------------- 学期
  Future<List<Term>> fetchTerms() async {
    final r = await http.get('/cjcx/cjcx_cxDgXscj.html', query: {'gnmkdm': 'N305005'});
    final years = _options(r.body, 'xnm');
    final qms = _options(r.body, 'xqm');
    final terms = <Term>[];
    final thisYear = DateTime.now().year + 1;
    for (final y in years) {
      final yi = int.tryParse(y.$1);
      if (yi != null && yi > thisYear) continue; // 别把未来的学年列出来
      for (final q in (qms.isEmpty ? const [(('3'), '第一学期'), (('12'), '第二学期')] : qms)) {
        terms.add(Term(xnm: y.$1, xqm: q.$1, label: '${y.$2} ${Term.termName(q.$1)}'));
      }
    }
    if (terms.isEmpty) {
      final y = DateTime.now().year;
      for (var i = 0; i < 4; i++) {
        for (final q in const ['3', '12']) {
          terms.add(Term(
            xnm: '${y - i}',
            xqm: q,
            label: '${y - i}-${y - i + 1} ${Term.termName(q)}',
          ));
        }
      }
    }
    return terms;
  }

  static List<(String, String)> _options(String html, String id) {
    final sel = RegExp('<select[^>]*id="$id"[^>]*>([\\s\\S]*?)</select>').firstMatch(html);
    if (sel == null) return const [];
    final body = sel.group(1)!;
    final out = <(String, String)>[];
    for (final m in RegExp(r'<option[^>]*value="([^"]*)"[^>]*>([^<]*)</option>').allMatches(body)) {
      final v = m.group(1)!.trim();
      if (v.isEmpty) continue;
      out.add((v, m.group(2)!.trim()));
    }
    return out;
  }

  static String _ms() => DateTime.now().millisecondsSinceEpoch.toString();
}
