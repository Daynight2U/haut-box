import 'package:flutter/material.dart';

import 'app_state.dart';
import '../core/theme/app_theme.dart';
import '../features/login/login_page.dart';
import '../features/shell/root_shell.dart';

class HautApp extends StatelessWidget {
  const HautApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final tier = s.blurTier;
        return MaterialApp(
          title: 'HAUT BOX',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: AppTheme.build(GlassTheme.light.withBlurTier(tier)),
          darkTheme: AppTheme.build(GlassTheme.dark.withBlurTier(tier)),
          home: s.loggedIn ? const RootShell() : const LoginPage(),
        );
      },
    );
  }
}
