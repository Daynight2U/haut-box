import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haut_box/data/api/zf_api.dart';
import 'package:haut_box/data/models/models.dart';

/// 用真实报文（tools/probe_haut.py 抓的）当夹具。
/// 学校哪天改了字段，这几个用例会先红，比在手机上发现强。
void main() {
  String read(String name) => File('test/fixtures/$name').readAsStringSync();

  group('真实课表报文', () {
    late ScheduleData data;
    setUpAll(() => data = ZfApi.parseSchedule(read('schedule.json'), xnm: '2026', xqm: '3'));

    test('学生信息', () {
      expect(data.student.name, '张同学');
      expect(data.student.id, '202400000001');
      expect(data.student.className, '示例2401');
      expect(data.student.major, '示例专业');
    });

    test('课程条数与关键字段', () {
      expect(data.courses.length, 17);
      final c = data.courses.first;
      expect(c.name, isNotEmpty);
      expect(c.day, inInclusiveRange(1, 7));
      expect(c.startPeriod, greaterThan(0));
      expect(c.endPeriod, greaterThanOrEqualTo(c.startPeriod));
      expect(c.weeks, isNotEmpty);
    });

    test('周次能解析出具体集合', () {
      final c = data.courses.firstWhere((x) => x.rawWeeks != null);
      expect(c.weeks.length, greaterThan(1));
      expect(c.weeks.every((w) => w >= 1 && w <= 30), true);
    });
  });

  group('真实考试报文', () {
    test('条数与时间解析', () {
      final items = ZfApi.parseExams(read('exam.json'));
      expect(items.length, 5);
      final e = items.first;
      expect(e.name, isNotEmpty);
      // "2026-12-15(16:20-18:20)" 这种格式必须解出具体时刻
      expect(items.where((x) => x.startAt != null).length, items.length);
      expect(e.startAt!.hour, greaterThanOrEqualTo(0));
      expect(e.room, isNotNull);
      expect(e.seat, isNotNull);
    });
  });

  group('真实成绩报文', () {
    test('条数、学分与绩点', () {
      final items = ZfApi.parseGrades(read('grade.json'), xqm: '12');
      expect(items.length, 14);
      final sum = GradeSummary.of(items);
      expect(sum.credits, greaterThan(0));
      expect(sum.gpa, inInclusiveRange(0, 5));
      expect(items.every((g) => g.name.isNotEmpty), true);
      expect(items.where((g) => g.score != null).length, items.length);
    });
  });
}
