import 'package:flutter/services.dart';

/// 桌面小组件桥。
///
/// App 只负责在拿到课表后写一份「日程快照」，原生读快照渲染。
/// 这样小组件既不联网、也不启动 Flutter 引擎，刷新成本接近 0。
class WidgetBridge {
  WidgetBridge._();

  static const MethodChannel _ch = MethodChannel('haut_box/widget');

  static Future<void> pushSnapshot(String json) async {
    try {
      await _ch.invokeMethod('saveSnapshot', {'json': json});
    } catch (_) {
      // 非安卓 / 测试环境，静默失败
    }
  }

  static Future<void> refresh() async {
    try {
      await _ch.invokeMethod('refresh');
    } catch (_) {}
  }

  /// 课前提醒开关（原生侧排闹钟）
  static Future<void> setReminders(bool on) async {
    try {
      await _ch.invokeMethod('setReminders', {'enabled': on});
    } catch (_) {}
  }

  /// 出分提醒
  static Future<void> notifyGrade({required String title, required String text}) async {
    try {
      await _ch.invokeMethod('notifyGrade', {'title': title, 'text': text});
    } catch (_) {}
  }
}
