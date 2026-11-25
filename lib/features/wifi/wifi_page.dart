import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/wifi/srun_client.dart';
import '../../core/wifi/wifi_channel.dart';
import '../../ui/glass/glass.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> with WidgetsBindingObserver {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  late final _user = TextEditingController(text: AppState.instance.studentId ?? '');
  final _pass = TextEditingController();
  final _ssid = TextEditingController(text: AppState.instance.wifiSsid);
  final _host = TextEditingController(text: AppState.instance.srunHost);
  final _port = TextEditingController(text: AppState.instance.srunPort);
  final _acId = TextEditingController(text: AppState.instance.srunAcId);

  bool _busy = false;
  String? _msg;
  bool _ok = false;
  bool _autoDiscover = true;
  String? _detected;
  bool _detecting = false;
  bool _batteryOptimized = false;
  Map<String, dynamic> _status = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secure.read(key: 'srun_pass').then((v) {
      if (v != null && mounted) setState(() => _pass.text = v);
    });
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in [_user, _pass, _ssid, _host, _port, _acId]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final st = await WifiChannel.status();
      final opt = await WifiChannel.isBatteryOptimized();
      if (mounted) {
        setState(() {
          _status = st;
          _autoDiscover = st['autoDiscover'] != false;
          final h = st['host']?.toString() ?? '';
          final p = st['port']?.toString() ?? '';
          if (h.isNotEmpty) _detected = '$h:$p';
          _batteryOptimized = opt;
        });
      }
    } on MissingPluginException {
      // 非安卓 / 测试环境：忽略
    } catch (_) {}
  }

  Future<void> _saveConfig({bool? enabled}) async {
    final s = AppState.instance;
    await s.setWifi(
      ssid: _ssid.text.trim(),
      host: _host.text.trim(),
      port: _port.text.trim(),
      acId: _acId.text.trim(),
    );
    await _secure.write(key: 'srun_pass', value: _pass.text);
    await WifiChannel.configure(
      ssid: _ssid.text.trim(),
      host: _host.text.trim(),
      port: _port.text.trim(),
      acId: _acId.text.trim(),
      user: _user.text.trim(),
      pass: _pass.text,
      enabled: enabled ?? s.autoAuth,
      autoDiscover: _autoDiscover,
    );
  }

  Future<void> _detectGateway() async {
    setState(() {
      _detecting = true;
      _msg = null;
    });
    try {
      final r = await WifiChannel.detectGateway();
      if (!mounted) return;
      setState(() {
        _detecting = false;
        if (r['ok'] == true) {
          _detected = '${r['host']}:${r['port']}';
          _host.text = r['host'].toString();
          _port.text = r['port'].toString();
          if (r['acId'] != null) _acId.text = r['acId'].toString();
          _ok = true;
          _msg = '识别到认证网关 ${r['host']}:${r['port']}（ac_id=${r['acId']}）';
        } else {
          _ok = false;
          _msg = '没识别到网关。确认已连上校园 WiFi（未认证状态），或手动填网关地址。';
        }
      });
    } on MissingPluginException {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _openPortal() async {
    try {
      final url = await WifiChannel.openPortal();
      if (mounted && url.isNotEmpty) {
        setState(() {
          _ok = true;
          _msg = '已用浏览器打开认证页：$url';
        });
      }
    } on MissingPluginException {
      /** 非安卓环境忽略 */
    }
  }

  Future<void> _toggleAuto(bool on) async {
    final s = AppState.instance;
    if (on) {
      if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
        setState(() {
          _ok = false;
          _msg = '先填校园网账号和密码，再开自动认证';
        });
        return;
      }
      await WifiChannel.requestNotificationPermission();
      if (_batteryOptimized) {
        await WifiChannel.requestIgnoreBattery();
      }
      await s.setWifi(auto: true);
      await _saveConfig(enabled: true);
    } else {
      await s.setWifi(auto: false);
      await _saveConfig(enabled: false);
      await WifiChannel.stop();
    }
    await _loadStatus();
  }

  Future<void> _authNow() async {
    FocusScope.of(context).unfocus();
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() {
        _ok = false;
        _msg = '先填校园网账号和密码';
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });

    bool ok = false;
    String message = '';
    try {
      await _saveConfig();
      final r = await WifiChannel.authNow();
      ok = r['ok'] == true;
      message = (r['message'] ?? '').toString();
    } on MissingPluginException {
      // 降级：Dart 侧直接发一次（老版本/非安卓）
      final client = SrunClient(
        host: _host.text.trim(),
        port: _port.text.trim(),
        acId: _acId.text.trim(),
      );
      final alive = await client.probe();
      if (!alive) {
        ok = false;
        message = '认证网关不可达，确认已连上校园 WiFi';
      } else {
        final r = await client.login(username: _user.text.trim(), password: _pass.text);
        ok = r.ok;
        message = r.message;
      }
    } on PlatformException catch (e) {
      ok = false;
      message = e.message ?? '认证失败';
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = ok;
      _msg = message;
    });
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.of(context);
    final s = AppState.instance;
    final running = _status['running'] == true;
    final lastStatus = (_status['lastStatus'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              GlassLargeTitle(
                title: '校园网',
                subtitle: '深澜 srun · 连上 WiFi 自动认证',
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
                    // 状态卡
                    GlassPanel(
                      radius: AppTokens.rXl,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: running ? const Color(0xFF2FA36B) : g.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  running ? '守护中' : '未启动',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: g.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lastStatus.isEmpty ? '开启下面的自动认证即可常驻' : lastStatus,
                                  style: TextStyle(fontSize: 11.5, color: g.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          Switch(value: s.autoAuth, onChanged: _toggleAuto),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassPanel(
                      radius: AppTokens.rXl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      child: Column(
                        children: [
                          _f('WiFi 名称', _ssid, 'STU_HAUT', g),
                          _f('校园网账号', _user, '学号', g, keyboard: TextInputType.number),
                          _f('校园网密码', _pass, '认证密码', g, obscure: true),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '自动识别网关',
                                      style: TextStyle(fontSize: 13.5, color: g.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '每个校区 IP 段都不一样，建议开着',
                                      style: TextStyle(fontSize: 11, color: g.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _autoDiscover,
                                onChanged: (v) async {
                                  setState(() => _autoDiscover = v);
                                  await _saveConfig();
                                },
                              ),
                            ],
                          ),
                          if (_autoDiscover)
                            _detectedRow(g)
                          else ...[
                            _f('认证网关', _host, '172.16.154.130', g, keyboard: TextInputType.url),
                            Row(children: [
                              Expanded(
                                child: _f('端口', _port, '69', g, keyboard: TextInputType.number),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _f('ac_id', _acId, '1', g, keyboard: TextInputType.number),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _busy ? null : _authNow,
                      child: Container(
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
                              color: AppTokens.hautBlue.withValues(alpha: .34),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                              spreadRadius: -6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '立即认证一次',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (_msg != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: (_ok ? const Color(0xFF2FA36B) : const Color(0xFFE24B4A))
                              .withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(AppTokens.rSm),
                          border: Border.all(
                            color: (_ok ? const Color(0xFF2FA36B) : const Color(0xFFE24B4A))
                                .withValues(alpha: .35),
                            width: .7,
                          ),
                        ),
                        child: Text(
                          _msg!,
                          style: TextStyle(fontSize: 12.5, height: 1.6, color: g.textPrimary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_batteryOptimized)
                      GlassPanel(
                        radius: AppTokens.rLg,
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        child: Row(
                          children: [
                            Icon(Icons.battery_alert_outlined, size: 20, color: g.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '系统可能会为了省电杀掉守护进程，建议允许本应用后台运行',
                                style: TextStyle(fontSize: 11.5, height: 1.5, color: g.textSecondary),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await WifiChannel.requestIgnoreBattery();
                              },
                              child: const Text('去设置', style: TextStyle(fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton.icon(
                        onPressed: _openPortal,
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text(
                          '认证不成功？用浏览器打开认证页',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '后台守护是前台服务，通知栏会常驻一条低优先级通知（不响不亮），'
                      '这是安卓保证不被杀的唯一正当方式。\n'
                      '只在「连着 WiFi 但没联网」时才发认证请求，平时零轮询。\n\n'
                      '网关地址会变：连上 WiFi 先别认证，用浏览器打开任意 http 网站，'
                      '地址栏跳转到的那个 IP 就是认证网关。',
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

  Widget _detectedRow(GlassTheme g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: g.isDark ? Colors.white.withValues(alpha: .05) : Colors.black.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(AppTokens.rSm - 2),
        border: Border.all(color: g.border, width: .7),
      ),
      child: Row(
        children: [
          Icon(Icons.radar_rounded, size: 16, color: g.textTertiary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _detecting
                  ? '正在识别…'
                  : (_detected == null ? '点右侧按钮识别网关' : '网关 $_detected'),
              style: TextStyle(fontSize: 12.5, color: g.textSecondary),
            ),
          ),
          TextButton(
            onPressed: _detecting ? null : _detectGateway,
            child: const Text('识别', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _f(
    String label,
    TextEditingController c,
    String hint,
    GlassTheme g, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text(label, style: TextStyle(fontSize: 11.5, color: g.textTertiary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: g.isDark ? Colors.white.withValues(alpha: .05) : Colors.black.withValues(alpha: .03),
              borderRadius: BorderRadius.circular(AppTokens.rSm - 2),
              border: Border.all(color: g.border, width: .7),
            ),
            child: TextField(
              controller: c,
              obscureText: obscure,
              keyboardType: keyboard,
              style: TextStyle(fontSize: 14, color: g.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 13, color: g.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
