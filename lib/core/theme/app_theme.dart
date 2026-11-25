import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// HAUT App 设计 token
///
/// 视觉基调：iOS 26 Liquid Glass —— 背景是静态极光，玻璃层折射它。
/// 关键点：模糊只用在"大块悬浮层"（导航、头部、卡片组），
/// 不做满屏小模糊，中端机才不掉帧。
class AppTokens {
  AppTokens._();

  // ---- 品牌色（后续换成学校 VI 只需改这里）----
  static const Color hautBlue = Color(0xFF2F6BFF);
  static const Color auroraTeal = Color(0xFF00C2A8);
  static const Color auroraViolet = Color(0xFF7A5CFF);
  static const Color auroraPink = Color(0xFFFF5C8A);

  // ---- 圆角（iOS 26 偏大圆角）----
  static const double rXs = 10;
  static const double rSm = 14;
  static const double rMd = 20;
  static const double rLg = 28;
  static const double rXl = 34;

  // ---- 间距 ----
  static const double gapXs = 6;
  static const double gapSm = 10;
  static const double gapMd = 16;
  static const double gapLg = 22;
  static const double gapXl = 30;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(18, 8, 18, 120);
}

/// 玻璃层的明暗参数。跟着 Theme 走，页面里读 `GlassTheme.of(context)`。
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  final Color panel; // 玻璃填充
  final Color panelStrong; // 更实的填充（表头/选中）
  final Color border; // 描边
  final Color highlight; // 顶部高光
  final Color shadow; // 投影
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color background; // 兜底背景色
  final List<Color> aurora; // 极光色团
  final double blurSigma; // 模糊强度
  final Brightness brightness;

  const GlassTheme({
    required this.panel,
    required this.panelStrong,
    required this.border,
    required this.highlight,
    required this.shadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.background,
    required this.aurora,
    required this.blurSigma,
    required this.brightness,
  });

  bool get isDark => brightness == Brightness.dark;

  static const dark = GlassTheme(
    panel: Color(0x14FFFFFF),
    panelStrong: Color(0x22FFFFFF),
    border: Color(0x29FFFFFF),
    highlight: Color(0x40FFFFFF),
    shadow: Color(0x66000000),
    textPrimary: Color(0xFFF3F6FF),
    textSecondary: Color(0xFFA8B2CC),
    textTertiary: Color(0xFF6E7893),
    accent: AppTokens.hautBlue,
    background: Color(0xFF070A15),
    aurora: [
      Color(0xFF2F6BFF),
      Color(0xFF00C2A8),
      Color(0xFF7A5CFF),
      Color(0xFFFF5C8A),
    ],
    blurSigma: 26,
    brightness: Brightness.dark,
  );

  static const light = GlassTheme(
    panel: Color(0xB8FFFFFF),
    panelStrong: Color(0xE6FFFFFF),
    border: Color(0x66FFFFFF),
    highlight: Color(0xCCFFFFFF),
    shadow: Color(0x1F2B3550),
    textPrimary: Color(0xFF10131C),
    textSecondary: Color(0xFF5B6579),
    textTertiary: Color(0xFF8D96A8),
    accent: AppTokens.hautBlue,
    background: Color(0xFFEEF2FB),
    aurora: [
      Color(0xFF6E96FF),
      Color(0xFF3FE0C6),
      Color(0xFFA98BFF),
      Color(0xFFFF9AB4),
    ],
    blurSigma: 26,
    brightness: Brightness.light,
  );

  /// 按"性能档位"降模糊。0=关闭模糊（纯半透明），1=轻，2=标准，3=强
  GlassTheme withBlurTier(int tier) {
    final sigma = switch (tier) {
      0 => 0.0,
      1 => 12.0,
      2 => 26.0,
      _ => 38.0,
    };
    return copyWith(blurSigma: sigma);
  }

  @override
  GlassTheme copyWith({
    Color? panel,
    Color? panelStrong,
    Color? border,
    Color? highlight,
    Color? shadow,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? background,
    List<Color>? aurora,
    double? blurSigma,
    Brightness? brightness,
  }) {
    return GlassTheme(
      panel: panel ?? this.panel,
      panelStrong: panelStrong ?? this.panelStrong,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      shadow: shadow ?? this.shadow,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      aurora: aurora ?? this.aurora,
      blurSigma: blurSigma ?? this.blurSigma,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    return GlassTheme(
      panel: Color.lerp(panel, other.panel, t)!,
      panelStrong: Color.lerp(panelStrong, other.panelStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      aurora: t < .5 ? aurora : other.aurora,
      blurSigma: ui_lerp(blurSigma, other.blurSigma, t),
      brightness: t < .5 ? brightness : other.brightness,
    );
  }

  static double ui_lerp(double a, double b, double t) => a + (b - a) * t;

  /// 取当前主题的玻璃参数
  static GlassTheme of(BuildContext context) {
    return Theme.of(context).extension<GlassTheme>() ?? GlassTheme.dark;
  }
}

class AppTheme {
  static ThemeData build(GlassTheme g) {
    final scheme = ColorScheme.fromSeed(
      seedColor: g.accent,
      brightness: g.brightness,
    ).copyWith(
      surface: g.background,
      primary: g.accent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: g.brightness,
      scaffoldBackgroundColor: g.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      fontFamilyFallback: const [
        'MiSans',
        'HarmonyOS Sans SC',
        'PingFang SC',
        'Noto Sans SC',
        'Microsoft YaHei',
      ],
      extensions: [g],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: g.textPrimary,
        displayColor: g.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: g.isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
        titleTextStyle: TextStyle(
          color: g.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: g.border.withValues(alpha: .5),
        thickness: .5,
        space: .5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: g.isDark ? const Color(0xFF1B2136) : Colors.white,
        contentTextStyle: TextStyle(color: g.textPrimary, fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
        ),
      ),
    );
  }
}
