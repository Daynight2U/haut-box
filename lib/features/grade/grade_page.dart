import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../ui/glass/glass.dart';
import '../../ui/glass/picker.dart';

/// 成绩页：按学期分开存，默认看本学期。
/// 顶部「学期 ⌄」下拉里第一项是「跳转到本学期」，与课表的「第 N 周 ⌄」保持一致。
class GradePage extends StatefulWidget {
  const GradePage({super.key});

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  Term? _selected; // null = 全部学期
  bool _picked = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final g = GlassTheme.of(context);
    final options = s.gradeTermOptions;

    if (!_picked) _selected = s.activeTerm ?? (options.isEmpty ? null : options.first);

    final items = _selected == null
        ? s.gradesOf(options)
        : (s.gradesByTerm[_selected!.key] ?? const <GradeItem>[]);
    final summary = GradeSummary.of(items);

    final at = _selected == null ? null : s.gradeAtOf(_selected!);
    final sub = items.isEmpty
        ? '暂无成绩'
        : '${summary.count} 门 · ${AppState.ageText(at).replaceFirst('数据截至 ', '')}';

    final waiting = _selected != null &&
        !s.gradesByTerm.containsKey(_selected!.key) &&
        s.gradeLoading;

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .4,
                      color: g.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '成绩',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          color: g.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      GlassPillButton(
                        label: _pillLabel(s),
                        onTap: options.isEmpty ? null : () => _pickTerm(context),
                      ),
                      const SizedBox(width: 7),
                      GlassIconButton(
                        icon: Icons.refresh_rounded,
                        size: 36,
                        iconSize: 18,
                        tooltip: '刷新',
                        onTap: () {
                          if (!_busy) _refresh(s);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: (waiting || _busy)
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : RefreshIndicator(
                      onRefresh: () => _refresh(s),
                      color: g.accent,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 2, 18, 120),
                        children: [
                          if (items.isNotEmpty) _SummaryCard(summary: summary),
                          const SizedBox(height: 16),
                          if (items.isEmpty)
                            _Empty(term: _selected)
                          else if (_selected != null)
                            for (final it in items) _GradeRow(item: it)
                          else
                            for (final t in options)
                              if ((s.gradesByTerm[t.key] ?? const []).isNotEmpty) ...[
                                _GroupLabel(text: t.displayLabel),
                                for (final it in s.gradesByTerm[t.key]!) _GradeRow(item: it),
                                const SizedBox(height: 6),
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

  String _pillLabel(AppState s) {
    if (_selected == null) return '全部学期';
    if (_selected!.key == s.activeTerm?.key) return '本学期';
    return _short(_selected!);
  }

  static String _short(Term t) {
    final y = int.tryParse(t.xnm);
    if (y == null) return t.displayLabel;
    final tail = (y + 1) % 100;
    final half = switch (t.xqm) {
      '3' => '上',
      '12' => '下',
      _ => '三',
    };
    return '${y % 100}-${tail.toString().padLeft(2, '0')} $half';
  }

  Future<void> _refresh(AppState s) async {
    setState(() => _busy = true);
    if (_selected != null) {
      await s.loadGrades(_selected!, force: true);
    } else {
      await s.loadAllGrades();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickTerm(BuildContext context) async {
    final s = AppState.instance;
    final options = s.gradeTermOptions;
    final picked = await showGlassPicker<_Sel>(
      context,
      title: '学期',
      items: [
        GlassPickerItem(
          label: '跳转到本学期',
          value: _Sel(s.activeTerm),
          hint: s.activeTerm == null ? null : _short(s.activeTerm!),
          selected: _selected != null && s.activeTerm != null && _selected!.key == s.activeTerm!.key,
          dividerAfter: true,
        ),
        GlassPickerItem(
          label: '全部学期',
          value: const _Sel(null),
          selected: _selected == null,
          dividerAfter: true,
        ),
        for (final t in options)
          GlassPickerItem(
            label: t.displayLabel,
            value: _Sel(t),
            selected: _selected != null && _selected!.key == t.key,
          ),
      ],
    );
    if (picked == null || !mounted) return;

    setState(() {
      _picked = true;
      _selected = picked.term;
      _busy = picked.term == null;
    });
    if (picked.term == null) {
      await s.loadAllGrades();
    } else {
      await s.loadGrades(picked.term!);
    }
    if (mounted) setState(() => _busy = false);
  }
}

class _Sel {
  const _Sel(this.term);
  final Term? term;
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: g.textTertiary,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final GradeSummary summary;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return GlassPanel(
      radius: AppTokens.rXl,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '平均绩点',
                style: TextStyle(fontSize: 11.5, letterSpacing: 1, color: g.textTertiary),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    summary.gpa.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 40,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.6,
                      color: g.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('/ 5.0', style: TextStyle(fontSize: 12, color: g.textTertiary)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _metric(context, '总学分', summary.credits.toStringAsFixed(1)),
              const SizedBox(height: 8),
              _metric(context, '课程数', '${summary.count}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final g = GlassTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: g.textTertiary)),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: g.textPrimary),
        ),
      ],
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.item});

  final GradeItem item;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final num = double.tryParse(item.score ?? '');
    final color = switch (num) {
      null => item.isPass == false ? const Color(0xFFE24B4A) : g.textSecondary,
      >= 90 => const Color(0xFF2FA36B),
      >= 60 => g.accent,
      _ => const Color(0xFFE24B4A),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: g.isDark ? Colors.white.withValues(alpha: .045) : Colors.white.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        border: Border.all(color: g.border.withValues(alpha: .55), width: .7),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (item.nature != null) ...[
                      Text(item.nature!, style: TextStyle(fontSize: 11, color: g.textTertiary)),
                      const SizedBox(width: 8),
                    ],
                    if (item.credit != null)
                      Text(
                        '${item.credit!.toStringAsFixed(item.credit! % 1 == 0 ? 0 : 1)} 学分',
                        style: TextStyle(fontSize: 11, color: g.textTertiary),
                      ),
                    if (item.gpa != null) ...[
                      const SizedBox(width: 8),
                      Text('绩点 ${item.gpa}', style: TextStyle(fontSize: 11, color: g.textTertiary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(
              item.score ?? '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: num != null ? 20 : 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -.4,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.term});

  final Term? term;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Icon(Icons.workspace_premium_outlined, size: 38, color: g.textTertiary),
          const SizedBox(height: 14),
          Text(
            term == null ? '还没有成绩' : '${term!.displayLabel} 没有成绩',
            style: TextStyle(fontSize: 15, color: g.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            term == null ? '下拉刷新试试' : '换个学期看看，或下拉刷新',
            style: TextStyle(fontSize: 12, color: g.textTertiary),
          ),
        ],
      ),
    );
  }
}
