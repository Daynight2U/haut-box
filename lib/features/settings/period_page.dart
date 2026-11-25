import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/glass/glass.dart';

/// 作息时间编辑。只有桌面小组件用到（课表本身不显示时刻）。
class PeriodPage extends StatefulWidget {
  const PeriodPage({super.key});

  @override
  State<PeriodPage> createState() => _PeriodPageState();
}

class _PeriodPageState extends State<PeriodPage> {
  Future<void> _pick(int index, bool isStart) async {
    final s = AppState.instance;
    final cur = s.periods[index];
    final raw = isStart ? cur.$1 : cur.$2;
    final parts = raw.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? '第 ${index + 1} 节 开始' : '第 ${index + 1} 节 结束',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: GlassTheme.of(ctx).isDark
                ? const Color(0xFF141A2B)
                : Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (isStart) {
      await s.setPeriod(index, text, cur.$2);
    } else {
      await s.setPeriod(index, cur.$1, text);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final g = GlassTheme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              GlassLargeTitle(
                title: '作息时间',
                subtitle: '小组件倒计时按这个算',
                trailing: GlassIconButton(
                  icon: Icons.close_rounded,
                  size: 36,
                  iconSize: 18,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
                  children: [
                    GlassPanel(
                      radius: AppTokens.rXl,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (var i = 0; i < s.periods.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: .5,
                                indent: 16,
                                endIndent: 16,
                                color: g.border.withValues(alpha: .5),
                              ),
                            _row(g, i, s.periods[i]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          for (var i = 0; i < PeriodTimes.defaults.length; i++) {
                            final p = PeriodTimes.defaults[i];
                            await s.setPeriod(i, p.$1, p.$2);
                          }
                          if (mounted) setState(() {});
                        },
                        child: const Text('恢复默认', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '各学院上课时间可能不一致，按自己课表上的时间改就行。\n'
                      '这个只影响桌面小组件显示的"还剩几分钟"，不影响课表本身。',
                      style: TextStyle(fontSize: 11, height: 1.8, color: g.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(GlassTheme g, int i, (String, String) p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              '第 ${i + 1} 节',
              style: TextStyle(fontSize: 13, color: g.textSecondary),
            ),
          ),
          const Spacer(),
          _chip(g, p.$1, () => _pick(i, true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('—', style: TextStyle(fontSize: 12, color: g.textTertiary)),
          ),
          _chip(g, p.$2, () => _pick(i, false)),
        ],
      ),
    );
  }

  Widget _chip(GlassTheme g, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: g.isDark ? Colors.white.withValues(alpha: .07) : Colors.black.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: g.border, width: .7),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
            color: g.textPrimary,
          ),
        ),
      ),
    );
  }
}
