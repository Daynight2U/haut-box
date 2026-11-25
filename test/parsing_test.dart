import 'package:flutter_test/flutter_test.dart';

import 'package:haut_box/data/models/models.dart';

void main() {
  group('周次解析', () {
    test('连续周', () {
      expect(Course.parseWeeks('1-16周'), List.generate(16, (i) => i + 1).toSet());
    });

    test('单周', () {
      expect(Course.parseWeeks('1-8周(单)'), {1, 3, 5, 7});
    });

    test('双周', () {
      expect(Course.parseWeeks('3-9周(双)'), {4, 6, 8});
    });

    test('零散周', () {
      expect(Course.parseWeeks('1,3,5,10周'), {1, 3, 5, 10});
    });

    test('空值不炸', () {
      expect(Course.parseWeeks(null), <int>{});
      expect(Course.parseWeeks(''), <int>{});
    });
  });

  group('节次解析', () {
    test('连堂', () {
      expect(Course.parsePeriods('1-2', null), (1, 2));
    });

    test('单节', () {
      expect(Course.parsePeriods('5', null), (5, 5));
    });

    test('脏数据兜底', () {
      final (s, e) = Course.parsePeriods('abc', null);
      expect(s, 1);
      expect(e, greaterThanOrEqualTo(s));
    });
  });

  group('绩点汇总', () {
    test('按学分加权', () {
      final sum = GradeSummary.of(const [
        GradeItem(name: 'A', credit: 4, gpa: 4.0),
        GradeItem(name: 'B', credit: 2, gpa: 2.0),
      ]);
      expect(sum.gpa, closeTo((4 * 4.0 + 2 * 2.0) / 6, 0.0001));
      expect(sum.credits, 6);
      expect(sum.count, 2);
    });

    test('没有绩点时不除零', () {
      final sum = GradeSummary.of(const [GradeItem(name: 'A', credit: 3)]);
      expect(sum.gpa, 0);
    });
  });

  group('及格判定', () {
    test('数字成绩', () {
      expect(GradeItem.fromJson(const {'kcmc': 'X', 'cj': '85'}).isPass, true);
      expect(GradeItem.fromJson(const {'kcmc': 'X', 'cj': '59'}).isPass, false);
    });
    test('等级成绩', () {
      expect(GradeItem.fromJson(const {'kcmc': 'X', 'cj': '优秀'}).isPass, true);
    });
  });
}
