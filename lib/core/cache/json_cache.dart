import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  const CacheEntry(this.raw, this.at);

  /// 接口原始报文（不是解析后的模型）—— 出问题时能直接看原文
  final String raw;
  final DateTime at;

  Duration get age => DateTime.now().difference(at);
}

/// 极简 JSON 缓存：按 (slot, variant) 存原始报文 + 抓取时间。
///
/// 为什么存原始报文而不是模型：
///   1. 学校改字段时，解析器可以事后修，旧数据不用重抓；
///   2. 解析逻辑变更不需要迁移缓存。
class JsonCache {
  JsonCache(this._prefs);

  final SharedPreferences _prefs;
  final Map<String, CacheEntry> _mem = {};

  static String _k(String slot, String variant) => 'jc::$slot::$variant';

  CacheEntry? get(String slot, String variant) {
    final k = _k(slot, variant);
    final hot = _mem[k];
    if (hot != null) return hot;
    final raw = _prefs.getString(k);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final e = CacheEntry(m['raw'] as String, DateTime.parse(m['at'] as String));
      _mem[k] = e;
      return e;
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String slot, String variant, String raw) async {
    final e = CacheEntry(raw, DateTime.now());
    _mem[_k(slot, variant)] = e;
    await _prefs.setString(
      _k(slot, variant),
      jsonEncode({'raw': raw, 'at': e.at.toIso8601String()}),
    );
  }

  bool isFresh(String slot, String variant, Duration ttl) {
    final e = get(slot, variant);
    return e != null && e.age < ttl;
  }

  void evict(String slot, String variant) => _mem.remove(_k(slot, variant));

  /// 清掉所有 cache:: 开头的键（退出登录时不用，登录态变化时才需要）
  Future<void> clearSlot(String slot) async {
    final prefix = 'jc::$slot::';
    _mem.removeWhere((k, _) => k.startsWith(prefix));
    for (final k in _prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await _prefs.remove(k);
    }
  }
}
