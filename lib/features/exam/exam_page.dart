import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../ui/glass/glass.dart';

class ExamPage extends StatelessWidget {
  const ExamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final now = DateTime.now();
    final all = s.exams;
    final upcoming = all.where((e) => e.startAt == null || e.startAt!.isAfter(now)).toList();
    final past = all.where((e) => e.startAt != null && e.startAt!.isBefore(now)).toList();

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassLargeTitle(
              title: '考试',
              subtitle: upcoming.isEmpty
                  ? '暂无待考安排'
                  : '还有 ${upcoming.length} 场待考',
              trailing: GlassIconButton(
                icon: Icons.refresh_rounded,
                tooltip: '刷新',
                onTap: () => s.refreshAll(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => s.refreshAll(),
                color: GlassTheme.of(context).accent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                  children: [
                    if (all.isEmpty)
                      const _Empty()
                    else ...[
                      if (upcoming.isNotEmpty) ...[
                        const _SectionLabel('即将到来'),
                        for (final e in upcoming) _ExamCard(item: e, highlight: true),
                      ],
                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const _SectionLabel('已结束'),
                        for (final e in past) _ExamCard(item: e, highlight: false),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: g.textTertiary,
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.item, required this.highlight});

  final ExamItem item;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final at = item.startAt;
    String? left;
    if (at != null) {
      final d = at.difference(DateTime.now());
      left = d.inDays >= 1 ? '${d.inDays} 天后' : (d.inHours >= 1 ? '${d.inHours} 小时后' : '即将开始');
    }
    final dateLabel = at == null
        ? (item.time ?? '时间待定')
        : '${at.month} 月 ${at.day} 日  ${PeriodTimes.weekFull[at.weekday - 1]}';

    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 12),
      radius: AppTokens.rLg,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.2,
                        color: g.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dateLabel,
                      style: TextStyle(fontSize: 12.5, color: g.textSecondary),
                    ),
                  ],
                ),
              ),
              if (left != null && highlight)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: g.accent.withValues(alpha: g.isDark ? .22 : .12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: g.accent.withValues(alpha: .4), width: .7),
                  ),
                  child: Text(
                    left,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: g.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (at != null) _tag(context, Icons.schedule, _timeRange(at, item.time)),
              if (item.room != null) _tag(context, Icons.place_outlined, item.room!),
              if (item.seat != null) _tag(context, Icons.event_seat_outlined, '座位 ${item.seat}'),
              if (item.mode != null) _tag(context, Icons.menu_book_outlined, item.mode!),
            ],
          ),
        ],
      ),
    );
  }

  String _timeRange(DateTime at, String? raw) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*[-~至]\s*(\d{1,2}):(\d{2})').firstMatch(raw ?? '');
    if (m != null) {
      return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)} - ${m.group(3)!.padLeft(2, '0')}:${m.group(4)}';
    }
    return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }

  Widget _tag(BuildContext context, IconData icon, String text) {
    final g = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: g.isDark ? Colors.white.withValues(alpha: .06) : Colors.black.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: g.textTertiary),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 11.5, color: g.textSecondary)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 38, color: g.textTertiary),
          const SizedBox(height: 14),
          Text('还没有考试安排', style: TextStyle(fontSize: 15, color: g.textSecondary)),
          const SizedBox(height: 6),
          Text(
            '教务排考后会自动出现在这里',
            style: TextStyle(fontSize: 12, color: g.textTertiary),
          ),
        ],
      ),
    );
  }
}
