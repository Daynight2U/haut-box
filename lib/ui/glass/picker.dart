import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'glass.dart';

class GlassPickerItem<T> {
  const GlassPickerItem({
    required this.label,
    required this.value,
    this.hint,
    this.selected = false,
    this.dividerAfter = false,
  });

  final String label;
  final T value;
  final String? hint;
  final bool selected;
  final bool dividerAfter;
}

/// 玻璃风格底部选择器。周次、学期、成绩学期都用它，保证观感一致。
Future<T?> showGlassPicker<T>(
  BuildContext context, {
  required String title,
  required List<GlassPickerItem<T>> items,
  double maxHeight = 420,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final g = GlassTheme.of(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
        child: GlassPanel(
          radius: AppTokens.rXl,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: g.textTertiary,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final it in items) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(AppTokens.rSm),
                          onTap: () => Navigator.of(ctx).pop(it.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    it.label,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: it.selected ? FontWeight.w600 : FontWeight.w500,
                                      color: it.selected ? g.accent : g.textPrimary,
                                    ),
                                  ),
                                ),
                                if (it.hint != null)
                                  Text(
                                    it.hint!,
                                    style: TextStyle(fontSize: 11, color: g.textTertiary),
                                  ),
                                if (it.selected) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.check_rounded, size: 17, color: g.accent),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (it.dividerAfter)
                          Divider(
                            height: 1,
                            indent: 12,
                            endIndent: 12,
                            color: g.border.withValues(alpha: .5),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 小胶囊按钮：用于「第 13 周 ⌄」「学期 ⌄」
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon = Icons.expand_more_rounded,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: g.isDark ? Colors.white.withValues(alpha: .07) : Colors.white.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: g.border, width: .8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 5)],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -.1,
                color: g.textPrimary,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 2),
              Icon(icon, size: 15, color: g.textTertiary),
            ],
          ],
        ),
      ),
    );
  }
}
