import 'dart:convert';
import 'dart:io';

/// 深澜 srun（Srun3k）Portal 认证。
///
/// 河南工业大学校园网认证网关：`172.16.154.130:69/cgi-bin/srun_portal`
/// 加密方式沿用学校客户端的做法（也是社区容器脚本里跑通的那套）：
///   - 用户名：每个字节 +4，前缀 "{SRUN3}\r\n"
///   - 密码：与 "1234567890" 逆序逐位 XOR，再把低/高 4 位分别加 0x36 / 0x63，
///           按索引奇偶交替拼接
///
/// 注意：这套 API 只在校园网内可达；且不同校区/网关固件可能要求额外参数，
/// 所以每个字段都做成可配置。
class SrunClient {
  SrunClient({
    required this.host,
    required this.port,
    required this.acId,
  });

  final String host;
  final String port;
  final String acId;

  Uri get _portal => Uri.parse('http://$host:$port/cgi-bin/srun_portal');

  static String encodeUsername(String raw) {
    final sb = StringBuffer('{SRUN3}\r\n');
    for (final b in utf8.encode(raw)) {
      sb.writeCharCode(b + 4);
    }
    return sb.toString();
  }

  static String encodePassword(String raw) {
    const key = '1234567890';
    final out = StringBuffer();
    final bytes = utf8.encode(raw);
    for (var i = 0; i < bytes.length; i++) {
      final k = bytes[i] ^ key.codeUnitAt(9 - (i % 10));
      final lo = (k & 0x0f) + 0x36;
      final hi = ((k >> 4) & 0x0f) + 0x63;
      if (i.isEven) {
        out.writeCharCode(lo);
        out.writeCharCode(hi);
      } else {
        out.writeCharCode(hi);
        out.writeCharCode(lo);
      }
    }
    return out.toString();
  }

  /// 先探一下网关在不在（判断是否真的连着校园网）
  Future<bool> probe() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.getUrl(Uri.parse('http://$host:$port/'));
      final resp = await req.close().timeout(const Duration(seconds: 5));
      await resp.drain<void>();
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<SrunResult> login({required String username, required String password}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final body = {
        'action': 'login',
        'n': '117',
        'mbytes': '0',
        'minutes': '0',
        'ac_id': acId,
        'mac': '02:00:00:00:00:00',
        'type': '3',
        'username': encodeUsername(username),
        'password': encodePassword(password),
        'drop': '0',
        'pop': '1',
      }
          .entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');

      final req = await client.postUrl(_portal);
      req.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      final bytes = utf8.encode(body);
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close().timeout(const Duration(seconds: 12));
      final raw = await resp.transform(utf8.decoder).join();
      final text = raw.trim();

      bool ok = false;
      String message = text;
      try {
        final j = jsonDecode(text);
        if (j is Map) {
          ok = j['error'] == 'ok' || j['res'] == 'ok' || j['error'] == 'ok';
          message = (j['error_msg'] ?? j['res'] ?? j['error'] ?? text).toString();
        }
      } catch (_) {
        ok = text.contains('login_ok') || text.toLowerCase().contains('success');
      }
      return SrunResult(ok: ok, message: message, raw: text, status: resp.statusCode);
    } on SocketException {
      return const SrunResult(
        ok: false,
        message: '连不上认证网关，确认已连上校园 WiFi',
      );
    } catch (e) {
      return SrunResult(ok: false, message: '认证请求失败：$e');
    } finally {
      client.close(force: true);
    }
  }
}

class SrunResult {
  const SrunResult({required this.ok, required this.message, this.raw, this.status});

  final bool ok;
  final String message;
  final String? raw;
  final int? status;
}
