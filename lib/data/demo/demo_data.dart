import '../models/models.dart';

/// 演示数据：未登录 / 接口不通时用来验证界面。
/// 刻意覆盖了单双周、连堂、同一天撞课这些真实情况。
class DemoData {
  DemoData._();

  static ScheduleData schedule() {
    Course c(String name, String room, String teacher, int day, int s, int e, String weeks) => Course(
          name: name,
          room: room,
          teacher: teacher,
          day: day,
          startPeriod: s,
          endPeriod: e,
          weeks: Course.parseWeeks(weeks),
          rawWeeks: weeks,
        );

    return ScheduleData(
      student: const StudentInfo(
        name: '演示同学',
        id: '202400000001',
        grade: '2024',
        major: '计算机科学与技术',
        className: '计科2401',
        currentWeek: 12,
        termName: '2026-2027 第一学期',
        totalWeeks: 20,
      ),
      courses: [
        c('高等数学 A(2)', '3 号楼 302', '王建华', 1, 1, 2, '1-16周'),
        c('大学物理', '2 号楼 105', '李娜', 1, 3, 4, '1-16周'),
        c('数据结构', '5 号楼 401', '张伟', 1, 7, 8, '1-8周'),
        c('体育（篮球）', '东区体育馆', '刘强', 2, 3, 4, '1-16周'),
        c('离散数学', '3 号楼 208', '陈晓', 2, 7, 8, '1-16周'),
        c('数据结构实验', '机房 A302', '张伟', 3, 1, 2, '3-16周(单)'),
        c('大学英语 III', '1 号楼 506', 'Emily', 3, 3, 4, '1-16周'),
        c('毛泽东思想概论', '4 号楼 201', '赵敏', 3, 5, 6, '1-16周'),
        c('操作系统', '5 号楼 302', '孙立', 4, 1, 2, '1-16周'),
        c('计算机网络', '5 号楼 305', '周涛', 4, 3, 4, '1-16周'),
        c('算法设计', '机房 A201', '张伟', 4, 7, 8, '3-16周(双)'),
        c('软件工程', '5 号楼 208', '吴敏', 5, 1, 2, '1-16周'),
        c('形势与政策', '4 号楼 101', '郑海', 5, 5, 6, '5-12周'),
      ],
      term: const Term(xnm: '2026', xqm: '3', label: '2026-2027 第一学期'),
    );
  }

  static List<ExamItem> exams() {
    final base = DateTime.now();
    return [
      ExamItem(
        name: '数据结构',
        time: '${base.year}-01-06 09:00-11:00',
        room: '5 号楼 401',
        seat: '23',
        mode: '闭卷',
        startAt: DateTime(base.year, 1, 6, 9),
      ),
      ExamItem(
        name: '高等数学 A(2)',
        time: '${base.year}-01-08 14:30-16:30',
        room: '3 号楼 302',
        seat: '08',
        mode: '闭卷',
        startAt: DateTime(base.year, 1, 8, 14, 30),
      ),
      ExamItem(
        name: '大学物理',
        time: '${base.year}-01-10 09:00-11:00',
        room: '2 号楼 105',
        seat: '31',
        mode: '开卷',
        startAt: DateTime(base.year, 1, 10, 9),
      ),
    ];
  }

  static List<GradeItem> grades() {
    return const [
      GradeItem(name: '数据结构', score: '92', credit: 4, gpa: 4.2, nature: '必修', term: '第一学期'),
      GradeItem(name: '高等数学 A(2)', score: '88', credit: 5, gpa: 3.8, nature: '必修', term: '第一学期'),
      GradeItem(name: '大学物理', score: '85', credit: 4, gpa: 3.5, nature: '必修', term: '第一学期'),
      GradeItem(name: '大学英语 III', score: '91', credit: 3, gpa: 4.1, nature: '必修', term: '第一学期'),
      GradeItem(name: '操作系统', score: '78', credit: 4, gpa: 2.8, nature: '必修', term: '第一学期'),
      GradeItem(name: '计算机网络', score: '95', credit: 3, gpa: 4.5, nature: '必修', term: '第一学期'),
      GradeItem(name: '体育（篮球）', score: '良好', credit: 1, gpa: 3.5, nature: '必修', term: '第一学期'),
    ];
  }

  static const List<Term> terms = [
    Term(xnm: '2026', xqm: '3', label: '2026-2027 第一学期'),
    Term(xnm: '2025', xqm: '12', label: '2025-2026 第二学期'),
    Term(xnm: '2025', xqm: '3', label: '2025-2026 第一学期'),
  ];
}
