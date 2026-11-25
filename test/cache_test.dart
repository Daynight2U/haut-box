import 'package:flutter_test/flutter_test.dart';
import 'package:haut_box/app/app_state.dart';
import 'package:haut_box/core/cache/json_cache.dart';
import 'package:haut_box/data/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JSON 缓存', () {
    late JsonCache cache;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cache = JsonCache(await SharedPreferences.getInstance());
    });

    test('没存过就是空', () {
      expect(cache.get('schedule', '2026-3'), isNull);
      expect(cache.isFresh('schedule', '2026-3', const Duration(hours: 1)), false);
    });

    test('存了能读回原文，并且算新鲜', () async {
      await cache.put('schedule', '2026-3', '{"kbList":[]}');
      expect(cache.get('schedule', '2026-3')!.raw, '{"kbList":[]}');
      expect(cache.isFresh('schedule', '2026-3', const Duration(hours: 1)), true);
    });

    test('不同学期互不覆盖', () async {
      await cache.put('schedule', '2026-3', 'A');
      await cache.put('schedule', '2025-12', 'B');
      expect(cache.get('schedule', '2026-3')!.raw, 'A');
      expect(cache.get('schedule', '2025-12')!.raw, 'B');
    });

    test('清空某个 slot 不影响别的', () async {
      await cache.put('schedule', '2026-3', 'A');
      await cache.put('grade', '2026-3', 'G');
      await cache.clearSlot('schedule');
      expect(cache.get('schedule', '2026-3'), isNull);
      expect(cache.get('grade', '2026-3')!.raw, 'G');
    });
  });

  group('TTL 策略', () {
    test('课表/考试 12 小时，往日成绩 7 天', () {
      expect(AppState.ttlOf('schedule'), const Duration(hours: 12));
      expect(AppState.ttlOf('exam'), const Duration(hours: 12));
      expect(AppState.ttlOf('terms'), const Duration(days: 7));
      expect(
        AppState.ttlOf('grade', isActiveTerm: false),
        const Duration(days: 7),
      );
    });

    test('本学期成绩在出分季更勤快', () {
      final ttl = AppState.ttlOf('grade');
      final m = DateTime.now().month;
      final season = m == 1 || m == 6 || m == 7;
      expect(ttl, season ? const Duration(minutes: 30) : const Duration(hours: 3));
    });
  });

  group('缓存时间文案', () {
    test('今天 / 昨天 / 更早', () {
      final now = DateTime.now();
      expect(AppState.ageText(now), startsWith('数据截至 今天'));
      expect(AppState.ageText(now.subtract(const Duration(days: 1))), startsWith('数据截至 昨天'));
      expect(
        AppState.ageText(now.subtract(const Duration(days: 5))),
        startsWith('数据截至 '),
      );
      expect(AppState.ageText(null), '尚未同步');
    });
  });

  group('学期键', () {
    test('缓存键是 2026-3 这种形式', () {
      expect(const Term(xnm: '2026', xqm: '3', label: '').key, '2026-3');
      expect(const Term(xnm: '2025', xqm: '12', label: '').key, '2025-12');
    });
  });
}
