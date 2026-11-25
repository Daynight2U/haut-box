import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/wifi/wifi_channel.dart';
import '../../ui/glass/glass.dart';
import '../settings/period_page.dart';
import '../wifi/wifi_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final g = GlassTheme.of(context);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
          children: [
            const GlassLargeTitle(title: '更多', subtitle: 'v$kAppVersion'),
            _AccountCard(),
            const SizedBox(height: 18),
            const _Label('外观'),
            GlassPanel(
              radius: AppTokens.rLg,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _SegRow(
                    label: '主题',
                    options: const ['跟随系统', '浅色', '深色'],
                    index: switch (s.themeMode) {
                      ThemeMode.system => 0,
                      ThemeMode.light => 1,
                      _ => 2,
                    },
                    onChanged: (i) => s.setThemeMode(
                      switch (i) { 0 => ThemeMode.system, 1 => ThemeMode.light, _ => ThemeMode.dark },
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: g.border.withValues(alpha: .5)),
                  _SegRow(
                    label: '模糊强度',
                    options: const ['关闭', '轻', '标准', '强'],
                    index: s.blurTier,
                    onChanged: s.setBlurTier,
                    hint: '中端机卡顿就调低',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _Label('功能'),
            GlassPanel(
              radius: AppTokens.rLg,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.wifi_rounded,
                    title: '校园网自动认证',
                    subtitle: '连上校园 WiFi 自动登录',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WifiPage()),
                    ),
                  ),
                  Divider(height: 1, indent: 50, endIndent: 16, color: g.border.withValues(alpha: .5)),
                  _NavRow(
                    icon: Icons.schedule_rounded,
                    title: '作息时间',
                    subtitle: '小组件倒计时按这个算',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PeriodPage()),
                    ),
                  ),
                  Divider(height: 1, indent: 50, endIndent: 16, color: g.border.withValues(alpha: .5)),
                  _SwitchRow(
                    icon: Icons.notifications_active_outlined,
                    title: '课前提醒',
                    subtitle: '上课前 12 分钟通知，离线也能响',
                    value: s.classRemind,
                    onChanged: (v) async {
                      if (v) await WifiChannel.requestNotificationPermission();
                      await s.setClassRemind(v);
                    },
                  ),
                  Divider(height: 1, indent: 50, endIndent: 16, color: g.border.withValues(alpha: .5)),
                  _NavRow(
                    icon: Icons.widgets_outlined,
                    title: '桌面小组件',
                    subtitle: '下一节课 / 今日课表，长按桌面添加',
                    onTap: () => _showWidgetHelp(context),
                  ),
                  Divider(height: 1, indent: 50, endIndent: 16, color: g.border.withValues(alpha: .5)),
                  _NavRow(
                    icon: Icons.play_circle_outline_rounded,
                    title: '载入演示数据',
                    subtitle: '没登录也能看课表/成绩长什么样',
                    onTap: () {
                      s.loadDemo();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已载入演示数据，去课表看看')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _Label('关于'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '非官方项目，数据来自河南工业大学教务系统公开网页接口。\n'
                    '账号密码只在本机提交给学校，不上传任何第三方服务器；App 不保存密码，只保存加密后的会话。',
                    style: TextStyle(fontSize: 11.5, height: 1.8, color: g.textTertiary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'v$kAppVersion · 正方 jwglxt 接口',
                    style: TextStyle(fontSize: 11, color: g.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 9),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
          color: g.textTertiary,
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final g = GlassTheme.of(context);
    final name = s.studentName ?? '未登录';
    final id = s.studentId ?? '—';
    return GlassPanel(
      radius: AppTokens.rXl,
      padding: const EdgeInsets.fromLTRB(17, 16, 14, 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTokens.hautBlue, AppTokens.auroraViolet],
              ),
            ),
            child: Center(
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(id, style: TextStyle(fontSize: 12, color: g.textTertiary)),
              ],
            ),
          ),
          if (s.loggedIn)
            TextButton(
              onPressed: () => _confirmLogout(context, s),
              style: TextButton.styleFrom(foregroundColor: g.textSecondary),
              child: const Text('退出登录', style: TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppState s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A2B),
        title: const Text('退出登录？', style: TextStyle(fontSize: 16)),
        content: const Text('本机会清除保存的会话，课表缓存保留。', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              s.logout();
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

class _SegRow extends StatelessWidget {
  const _SegRow({
    required this.label,
    required this.options,
    required this.index,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: g.textPrimary)),
              const Spacer(),
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < options.length; i++)
                    GlassChip(
                      label: options[i],
                      dense: true,
                      selected: i == index,
                      onTap: () => onChanged(i),
                    ),
                ],
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(hint!, style: TextStyle(fontSize: 11, color: g.textTertiary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: g.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, color: g.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: g.textTertiary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: g.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// 各家桌面找小组件的路径都不一样，干脆一次列全
void _showWidgetHelp(BuildContext context) {
  final g = GlassTheme.of(context);
  const items = [
    ('通用', '长按桌面空白处 → 小组件 → 找到「HAUT」→ 拖出 2×2 或 4×2'),
    ('小米 / HyperOS', '长按桌面 → 添加小部件 → 搜索 HAUT；首次可能要求在「安全中心」放开自启动'),
    ('vivo / OriginOS', '长按桌面 → 原子组件 / 小部件 → HAUT'),
    ('OPPO / ColorOS', '长按桌面 → 添加 → 小部件 → HAUT'),
    ('华为 / 荣耀', '桌面双指向内捏合 → 窗口小工具 → HAUT'),
  ];
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
      child: GlassPanel(
        radius: AppTokens.rXl,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '添加桌面小组件',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -.3,
                color: g.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '组件只读本地快照，不联网；上下课时自动刷新',
              style: TextStyle(fontSize: 11.5, color: g.textTertiary),
            ),
            const SizedBox(height: 14),
            for (final it in items) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.$1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: g.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      it.$2,
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: g.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: g.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(title, style: TextStyle(fontSize: 14.5, color: g.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: g.textTertiary)),
                const SizedBox(height: 6),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
