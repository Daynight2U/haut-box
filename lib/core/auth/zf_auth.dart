import 'dart:convert';

import '../net/zf_http.dart';
import 'zf_rsa.dart';

/// 正方统一登录（学号 + 教务密码）
///
/// 实测流程（HAUT jwglxt，2026-11）：
///   1. GET  /xtgl/login_slogin.html        → csrftoken（形如 "uuid,去横线uuid"）
///   2. GET  /xtgl/login_getPublicKey.html  → {"modulus":..., "exponent":"AQAB"}
///   3. POST /xtgl/login_slogin.html?time=  → yhm / mm(RSA) / csrftoken / language
///   4. GET  /xtgl/index_initMenu.html      → 仍 302 到登录页即失败
///
/// 注意：csrftoken 要整串提交（正方是原生 form.submit()，不做拆分）。
class ZfAuth {
  ZfAuth(this.http);

  final ZfHttp http;

  static final _csrfRe = RegExp(r'id="csrftoken"[^>]*value="([^"]+)"');
  static final _failRe = RegExp(r'用户名或密码不正确|用户不存在|密码错误');

  Future<void> login(String username, String password) async {
    final page = await http.get('/xtgl/login_slogin.html', query: {'time': _ms()});
    if (page.status != 200) {
      throw ZfException('教务登录页打不开（HTTP ${page.status}）');
    }
    final m = _csrfRe.firstMatch(page.body);
    if (m == null) {
      throw ZfException('登录页结构异常：找不到 csrftoken，学校可能升级了系统');
    }
    final token = m.group(1)!;

    // 页面开关：验证码 / 密码加密
    final needCaptcha = _flag(page.body, 'dlsfbxyzm');
    if (needCaptcha == '1') {
      throw ZfException('学校已开启登录验证码，需要走网页登录后再导入会话', code: 'captcha');
    }

    final pk = await http.get('/xtgl/login_getPublicKey.html', query: {'time': _ms()}, ajax: true);
    if (pk.status != 200 || !pk.isJson) {
      throw ZfException('取登录公钥失败（HTTP ${pk.status}）');
    }
    final key = pk.json as Map<String, dynamic>;
    final rsa = ZfRsa(
      modulusB64: key['modulus'] as String,
      exponentB64: key['exponent'] as String,
    );

    final resp = await http.postForm(
      '/xtgl/login_slogin.html',
      {
        'yhm': username,
        'mm': rsa.encrypt(password),
        'csrftoken': token,
        'language': 'zh_CN',
      },
      query: {'time': _ms()},
      ajax: false,
      // 不自动跟随：要把 302 这一跳的 Set-Cookie 收下来
      followRedirects: false,
    );

    final hit = _failRe.firstMatch(resp.body);
    if (hit != null) {
      throw ZfException('学号或密码不正确（教务系统返回：${hit.group(0)}）', code: 'bad_credentials');
    }
    if (resp.status >= 400) {
      throw ZfException('登录请求被拒绝（HTTP ${resp.status}）', code: 'http_${resp.status}');
    }

    // 验证会话真的建立了
    final menu = await http.get('/xtgl/index_initMenu.html', query: {'jsdm': '', '_t': _ms()}, ajax: true);
    final redirected = menu.finalPath.contains('login_slogin');
    final stillLoginPage = menu.body.contains('id="csrftoken"');
    if (redirected || stillLoginPage) {
      throw ZfException('登录未生效，可能有其他校验（会话被踢或需要统一身份认证）', code: 'session_invalid');
    }
  }

  Future<void> logout() async {
    try {
      await http.get('/xtgl/logout.html');
    } catch (_) {}
    http.clearCookies();
  }

  static String? _flag(String html, String id) {
    final m = RegExp('id="$id"[^>]*value="?([^"\\s>]*)"?').firstMatch(html);
    return m?.group(1);
  }

  static String _ms() => DateTime.now().millisecondsSinceEpoch.toString();

  /// 探测：这个学期有哪些课（用于登录后判断 xnm/xqm）
  static Map<String, String> parseFlags(String html) {
    return {
      'captcha': _flag(html, 'dlsfbxyzm') ?? '?',
      'encrypt': _flag(html, 'mmsfjm') ?? '?',
    };
  }

  static String prettyJson(Object? o) => const JsonEncoder.withIndent('  ').convert(o);
}
