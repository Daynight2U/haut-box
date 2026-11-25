import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ZfException implements Exception {
  ZfException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ZfResponse {
  ZfResponse({
    required this.status,
    required this.body,
    required this.finalPath,
    required this.headers,
  });

  final int status;
  final String body;
  final String finalPath;
  final Map<String, List<String>> headers;

  bool get isJson {
    final t = body.trimLeft();
    return t.startsWith('{') || t.startsWith('[');
  }

  dynamic get json => jsonDecode(body);
}

/// 极简 HTTP 客户端：自己管 Cookie。
///
/// 正方只需要 JSESSIONID 一个会话，用 dio + cookie_manager 反而更重；
/// 这里用 dart:io 直连，零依赖，重定向也能看到最终地址。
class ZfHttp {
  ZfHttp({String base = 'https://jwglxt.haut.edu.cn', String contextPath = '/jwglxt'})
      : _base = base,
        _context = contextPath;

  final String _base;
  final String _context;
  final Map<String, String> _cookies = {};
  HttpClient? _client;

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  void restoreCookies(Map<String, String> c) {
    _cookies
      ..clear()
      ..addAll(c);
  }

  void clearCookies() => _cookies.clear();

  HttpClient get _http {
    final c = _client ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 20)
      ..userAgent = _ua;
    return c;
  }

  Uri uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$_base$_context$path');
    return query == null || query.isEmpty ? u : u.replace(queryParameters: query);
  }

  Future<ZfResponse> get(String path, {Map<String, String>? query, bool ajax = false}) {
    return _send('GET', path, query: query, ajax: ajax);
  }

  Future<ZfResponse> postForm(
    String path,
    Map<String, String> form, {
    Map<String, String>? query,
    bool ajax = true,
    bool followRedirects = true,
  }) {
    return _send('POST', path, query: query, form: form, ajax: ajax, follow: followRedirects);
  }

  Future<ZfResponse> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? form,
    bool ajax = false,
    bool follow = true,
  }) async {
    final target = uri(path, query);
    try {
      final req = await _http.openUrl(method, target);
      // 手动处理跳转：正方登录后是 302，自动跟随会丢掉那一跳的 Set-Cookie
      req.followRedirects = follow;
      req.headers.set(HttpHeaders.acceptHeader,
          ajax ? 'application/json, text/javascript, */*; q=0.01' : 'text/html,application/xhtml+xml,*/*');
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh;q=0.9');
      req.headers.set(HttpHeaders.refererHeader, uri('/xtgl/login_slogin.html').toString());
      if (ajax) {
        req.headers.set('X-Requested-With', 'XMLHttpRequest');
      }
      if (_cookies.isNotEmpty) {
        req.headers.set(HttpHeaders.cookieHeader,
            _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
      }
      if (form != null) {
        final body = form.entries
            .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&');
        final bytes = utf8.encode(body);
        req.headers.contentType =
            ContentType('application', 'x-www-form-urlencoded', charset: 'UTF-8');
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final resp = await req.close().timeout(const Duration(seconds: 25));
      _absorbCookies(resp);
      final raw = await resp
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk))
          .timeout(const Duration(seconds: 30));
      final text = utf8.decode(raw, allowMalformed: true);
      final finalPath = resp.redirects.isEmpty
          ? target.toString()
          : target.resolveUri(resp.redirects.last.location).toString();
      final headers = <String, List<String>>{};
      resp.headers.forEach((k, v) => headers[k] = v);
      return ZfResponse(status: resp.statusCode, body: text, finalPath: finalPath, headers: headers);
    } on SocketException catch (e) {
      throw ZfException('连不上教务系统，检查网络或校园网是否已认证（${e.osError?.message ?? 'socket'}）');
    } on TimeoutException {
      throw ZfException('教务系统响应超时，稍后重试');
    } on HandshakeException {
      throw ZfException('HTTPS 握手失败，可能是校园网网关劫持，请先完成校园网认证');
    }
  }

  void _absorbCookies(HttpClientResponse resp) {
    for (final c in resp.cookies) {
      if (c.value.isEmpty || c.maxAge == 0) {
        _cookies.remove(c.name);
      } else {
        _cookies[c.name] = c.value;
      }
    }
  }

  void dispose() {
    _client?.close(force: true);
    _client = null;
  }
}
