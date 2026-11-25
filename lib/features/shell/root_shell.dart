import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/glass/glass.dart';
import '../exam/exam_page.dart';
import '../grade/grade_page.dart';
import '../more/more_page.dart';
import '../schedule/schedule_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _items = [
    NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded, label: '课表'),
    NavItem(icon: Icons.event_note_outlined, activeIcon: Icons.event_note_rounded, label: '考试'),
    NavItem(icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: '成绩'),
    NavItem(icon: Icons.widgets_outlined, activeIcon: Icons.widgets_rounded, label: '更多'),
  ];

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              SchedulePage(),
              ExamPage(),
              GradePage(),
              MorePage(),
            ],
          ),
          if (AppState.instance.offline)
            Positioned(
              top: MediaQuery.of(context).padding.top + 4,
              left: 18,
              right: 18,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9A319).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: const Color(0xFFE9A319).withValues(alpha: .4),
                      width: .7,
                    ),
                  ),
                  child: Text(
                    '离线：显示的是本地缓存',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: g.textSecondary),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 22,
            right: 22,
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 4
                : 16,
            child: GlassNavBar(
              index: _index,
              items: _items,
              onChanged: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}
