package cn.edu.haut.hautbox

import android.content.Intent
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "haut_box/wifi"
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 小组件：只接收快照 + 触发重绘，不做任何网络请求
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "haut_box/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveSnapshot" -> {
                        val json = call.argument<String>("json")
                        if (json.isNullOrBlank()) {
                            result.error("EMPTY", "快照为空", null)
                        } else {
                            cn.edu.haut.hautbox.widget.WidgetData.save(this, json)
                            cn.edu.haut.hautbox.widget.WidgetRenderer.updateAll(this)
                            result.success(true)
                        }
                    }

                    "refresh" -> {
                        cn.edu.haut.hautbox.widget.WidgetRenderer.updateAll(this)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val cfg = AuthConfig(this)
                        cfg.ssid = call.argument<String>("ssid") ?: cfg.ssid
                        cfg.host = call.argument<String>("host") ?: cfg.host
                        cfg.port = call.argument<String>("port") ?: cfg.port
                        cfg.acId = call.argument<String>("acId") ?: cfg.acId
                        cfg.user = call.argument<String>("user") ?: cfg.user
                        call.argument<Boolean>("autoDiscover")?.let { cfg.autoDiscover = it }
                        call.argument<String>("pass")?.let { cfg.pass = it }
                        cfg.enabled = call.argument<Boolean>("enabled") ?: cfg.enabled
                        if (cfg.enabled && cfg.ready) WifiAuthService.start(this) else WifiAuthService.stop(this)
                        result.success(statusMap())
                    }

                    "start" -> {
                        val cfg = AuthConfig(this)
                        cfg.enabled = true
                        if (!cfg.ready) {
                            result.error("NO_CREDENTIALS", "还没填账号密码", null)
                            return@setMethodCallHandler
                        }
                        WifiAuthService.start(this)
                        result.success(true)
                    }

                    "stop" -> {
                        AuthConfig(this).enabled = false
                        WifiAuthService.stop(this)
                        result.success(true)
                    }

                    "status" -> result.success(statusMap())

                    "detectGateway" -> {
                        val cfg = AuthConfig(this)
                        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                        Thread {
                            val net = PortalProbe.wifiNetwork(cm)
                            val gw = PortalProbe.discover(cm, net, cfg.host, cfg.port, cfg.acId)
                            main.post {
                                result.success(
                                    mapOf(
                                        "ok" to gw.host.isNotBlank(),
                                        "host" to gw.host,
                                        "port" to gw.port,
                                        "acId" to (gw.acId ?: cfg.acId),
                                    )
                                )
                            }
                        }.apply { isDaemon = true }.start()
                    }

                    "authNow" -> {
                        val cfg = AuthConfig(this)
                        if (!cfg.ready) {
                            result.error("NO_CREDENTIALS", "还没填账号密码", null)
                            return@setMethodCallHandler
                        }
                        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                        Thread {
                            val net = PortalProbe.wifiNetwork(cm)
                            val gw = if (cfg.autoDiscover) {
                                PortalProbe.discover(cm, net, cfg.host, cfg.port, cfg.acId)
                            } else {
                                PortalProbe.Gateway(cfg.host, cfg.port, cfg.acId)
                            }
                            if (cfg.autoDiscover) {
                                cfg.host = gw.host
                                cfg.port = gw.port
                                gw.acId?.let { cfg.acId = it }
                            }
                            val r = SrunAuth.login(
                                gw.host, gw.port, gw.acId ?: cfg.acId, cfg.user, cfg.pass, net,
                            )
                            main.post {
                                result.success(
                                    mapOf(
                                        "ok" to r.ok,
                                        "message" to r.message,
                                        "host" to gw.host,
                                        "port" to gw.port,
                                        "acId" to (gw.acId ?: cfg.acId),
                                    )
                                )
                            }
                        }.apply { isDaemon = true }.start()
                    }

                    "openPortal" -> {
                        val cfg = AuthConfig(this)
                        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                        Thread {
                            val net = PortalProbe.wifiNetwork(cm)
                            val gw = PortalProbe.discover(cm, net, cfg.host, cfg.port, cfg.acId)
                            if (gw.host.isNotBlank()) {
                                cfg.host = gw.host
                                cfg.port = gw.port
                                gw.acId?.let { cfg.acId = it }
                            }
                            val url = PortalProbe.portalPage(this, gw)
                            main.post {
                                runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
                                result.success(url)
                            }
                        }.apply { isDaemon = true }.start()
                    }

                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 9001)
                        }
                        result.success(true)
                    }

                    "batteryOptimized" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                    }

                    "requestIgnoreBattery" -> {
                        runCatching {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                )
                            )
                        }.onFailure {
                            runCatching {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            }
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun statusMap(): Map<String, Any> {
        val cfg = AuthConfig(this)
        return mapOf(
            "running" to WifiAuthService.running,
            "lastStatus" to WifiAuthService.lastStatus,
            "lastOk" to WifiAuthService.lastOk,
            "enabled" to cfg.enabled,
            "ready" to cfg.ready,
            "host" to cfg.host,
            "port" to cfg.port,
            "autoDiscover" to cfg.autoDiscover,
        )
    }
}
