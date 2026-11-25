import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/glass/glass.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController(text: '');
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final s = AppState.instance;
    final u = _user.text.trim();
    final p = _pass.text;
    if (u.isEmpty || p.isEmpty) {
      _toast('学号和密码都要填');
      return;
    }
    final ok = await s.login(u, p);
    if (!mounted) return;
    if (!ok && s.error != null) {
      _toast(s.error!);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final s = AppState.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _Logo(),
                  const SizedBox(height: 26),
                  Text(
                    'HAUT BOX',
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                      color: g.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '河南工业大学 · 课表 考试 成绩 校园网',
                    style: TextStyle(
                      fontSize: 12.5,
                      letterSpacing: .8,
                      color: g.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  GlassPanel(
                    radius: AppTokens.rXl,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Field(
                          controller: _user,
                          hint: '学号',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _pass,
                          hint: '教务系统密码',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          suffix: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 19,
                              color: g.textTertiary,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _LoginButton(loading: s.loading, onTap: s.loading ? null : _submit),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '首次登录密码一般是 HGD + 身份证后 6 位。\n'
                      '账号密码只在本机向学校教务系统提交，不经过任何第三方服务器。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, height: 1.7, color: g.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTokens.hautBlue, AppTokens.auroraViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTokens.hautBlue.withValues(alpha: .45),
            blurRadius: 34,
            offset: const Offset(0, 14),
            spreadRadius: -8,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: .28), width: .9),
      ),
      child: Center(
        child: Text(
          'H',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: .96),
            letterSpacing: -2,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: .2), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: g.isDark ? Colors.white.withValues(alpha: .06) : Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        border: Border.all(color: g.border, width: .8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: g.textTertiary),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: TextStyle(fontSize: 15, color: g.textPrimary, letterSpacing: .2),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14.5, color: g.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4C82FF), Color(0xFF2A5EE0)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTokens.hautBlue.withValues(alpha: .38),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  '登录',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
