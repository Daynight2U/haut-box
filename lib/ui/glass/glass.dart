import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 静态极光背景。
/// 用径向渐变堆出来，不用实时模糊 —— 玻璃层会去模糊它，
/// 背景本身再模糊就是白烧 GPU（中端机直接掉帧）。
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final dark = g.isDark;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF070A15), Color(0xFF0B1024), Color(0xFF0A0E1C)]
                    : const [Color(0xFFF3F6FE), Color(0xFFE9EEFB), Color(0xFFF6F8FF)],
              ),
            ),
          ),
          Positioned(
            left: -140,
            top: -120,
            child: _Blob(color: g.aurora[0], size: 520, opacity: dark ? .55 : .55),
          ),
          Positioned(
            right: -160,
            top: 40,
            child: _Blob(color: g.aurora[1], size: 440, opacity: dark ? .38 : .40),
          ),
          Positioned(
            left: -80,
            bottom: -180,
            child: _Blob(color: g.aurora[2], size: 520, opacity: dark ? .42 : .34),
          ),
          Positioned(
            right: -120,
            bottom: -140,
            child: _Blob(color: g.aurora[3], size: 360, opacity: dark ? .22 : .26),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * .35),
              color.withValues(alpha: 0),
            ],
            stops: const [0, .45, 1],
          ),
        ),
      ),
    );
  }
}

/// 玻璃面板：真模糊 + 渐变填充 + 顶部高光描边。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppTokens.rLg,
    this.blurSigma,
    this.tint,
    this.opacity = 1,
    this.showBorder = true,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? blurSigma;
  final Color? tint;
  final double opacity;
  final bool showBorder;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final sigma = blurSigma ?? g.blurSigma;
    final fill = (tint ?? g.panel);

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: clipBehavior,
      child: Stack(
        children: [
          // 背景模糊层
          if (sigma > 0)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
                child: const SizedBox.expand(),
              ),
            ),
          // 玻璃填充 + 描边
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: g.isDark
                      ? [
                          fill.withValues(alpha: (fill.a * 1.35).clamp(0.0, 1.0)),
                          fill,
                        ]
                      : [fill, fill.withValues(alpha: fill.a * .82)],
                ),
                border: showBorder
                    ? Border.all(color: g.border, width: .8)
                    : null,
              ),
            ),
          ),
          // 顶部高光（Liquid Glass 的关键细节）
          Positioned(
            left: radius * .6,
            right: radius * .6,
            top: 0,
            child: Container(
              height: .9,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    g.highlight.withValues(alpha: 0),
                    g.highlight,
                    g.highlight.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );

    content = Opacity(opacity: opacity, child: content);

    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: g.shadow,
            blurRadius: 26,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: content,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }
    return content;
  }
}

/// 悬浮的胶囊导航条。
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.index,
    required this.items,
    required this.onChanged,
  });

  final int index;
  final List<NavItem> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return GlassPanel(
      radius: 30,
      padding: const EdgeInsets.all(6),
      blurSigma: g.blurSigma + 6,
      child: SizedBox(
        height: 56,
        child: LayoutBuilder(
          builder: (context, box) {
            final itemW = box.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    items.length == 1 ? 0 : -1 + 2 * index / (items.length - 1),
                    0,
                  ),
                  child: Container(
                    width: itemW,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: g.isDark
                          ? Colors.white.withValues(alpha: .10)
                          : Colors.black.withValues(alpha: .06),
                      border: Border.all(
                        color: g.isDark
                            ? Colors.white.withValues(alpha: .10)
                            : Colors.white.withValues(alpha: .8),
                        width: .8,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _NavButton(
                          item: items[i],
                          selected: i == index,
                          onTap: () => onChanged(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NavItem {
  const NavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final color = selected ? g.textPrimary : g.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.06 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: Icon(selected ? item.activeIcon : item.icon, size: 22, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10.5,
                height: 1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 大标题头（滚动时下滑出玻璃底）。
class GlassLargeTitle extends StatelessWidget {
  const GlassLargeTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.scrollOffset = 0,
    this.onSubtitleTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double scrollOffset;
  final VoidCallback? onSubtitleTap;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final collapsed = (scrollOffset / 64).clamp(0.0, 1.0);
    return Stack(
      children: [
        // 收起后的玻璃条
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: collapsed,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: g.blurSigma * collapsed,
                    sigmaY: g.blurSigma * collapsed,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: g.isDark
                          ? Colors.black.withValues(alpha: .28)
                          : Colors.white.withValues(alpha: .55),
                      border: Border(
                        bottom: BorderSide(color: g.border.withValues(alpha: .4), width: .5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: GestureDetector(
                          onTap: onSubtitleTap,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: .4,
                                    color: g.textTertiary,
                                  ),
                                ),
                              ),
                              if (onSubtitleTap != null) ...[
                                const SizedBox(width: 3),
                                Icon(Icons.expand_more_rounded, size: 14, color: g.textTertiary),
                              ],
                            ],
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                        color: g.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}

/// 小胶囊按钮 / 标签
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 15, vertical: dense ? 7 : 9),
        decoration: BoxDecoration(
          color: selected
              ? g.accent.withValues(alpha: g.isDark ? .28 : .16)
              : (g.isDark ? Colors.white.withValues(alpha: .07) : Colors.white.withValues(alpha: .6)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? g.accent.withValues(alpha: .55) : g.border,
            width: .8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? g.accent : g.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: dense ? 12 : 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? g.textPrimary : g.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 毛玻璃图标按钮
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final btn = GlassPanel(
      radius: size / 2,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: Icon(icon, size: iconSize, color: g.textSecondary)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
