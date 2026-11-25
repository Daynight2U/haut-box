import 'package:flutter/services.dart';

/// 与原生校园网守护服务通信。
///
/// 认证本身在 Kotlin 里做（见 android/.../SrunAuth.kt），这里只负责
/// 下发配置、开关服务、查状态。原生不可用时（比如跑测试）会抛
/// MissingPluginException，调用方自行降级。
class WifiChannel {
  WifiChannel._();

  static const MethodChannel _ch = MethodChannel('haut_box/wifi');

  static Future<Map<String, dynamic>> configure({
    required String ssid,
    required String host,
    required String port,
    required String acId,
    required String user,
    required String pass,
    required bool enabled,
    bool autoDiscover = true,
  }) async {
    final r = await _ch.invokeMethod<Map>('configure', {
      'ssid': ssid,
      'host': host,
      'port': port,
      'acId': acId,
      'user': user,
      'pass': pass,
      'enabled': enabled,
      'autoDiscover': autoDiscover,
    });
    return (r ?? {}).cast<String, dynamic>();
  }

  /// 自动识别认证网关（探测重定向 + 默认网关）
  static Future<Map<String, dynamic>> detectGateway() async {
    final r = await _ch.invokeMethod<Map>('detectGateway');
    return (r ?? {}).cast<String, dynamic>();
  }

  /// 打不开自动化时的兜底：用浏览器打开学校认证页
  static Future<String> openPortal() async {
    final r = await _ch.invokeMethod<String>('openPortal');
    return r ?? '';
  }

  static Future<void> start() => _ch.invokeMethod('start');

  static Future<void> stop() => _ch.invokeMethod('stop');

  static Future<Map<String, dynamic>> status() async {
    final r = await _ch.invokeMethod<Map>('status');
    return (r ?? {}).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> authNow() async {
    final r = await _ch.invokeMethod<Map>('authNow');
    return (r ?? {}).cast<String, dynamic>();
  }

  static Future<void> requestNotificationPermission() async {
    await _ch.invokeMethod('requestNotificationPermission');
  }

  static Future<bool> isBatteryOptimized() async {
    final v = await _ch.invokeMethod<bool>('batteryOptimized');
    return v ?? false;
  }

  static Future<void> requestIgnoreBattery() async {
    await _ch.invokeMethod('requestIgnoreBattery');
  }
}
