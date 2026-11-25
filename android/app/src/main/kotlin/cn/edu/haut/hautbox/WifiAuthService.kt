package cn.edu.haut.hautbox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 校园网守护服务。
 *
 * 设计要点（都是为了"常驻但不费电"）：
 *   1. 事件驱动：只在系统告诉我们「WiFi 连上了但没有网络」时才发认证请求，不轮询；
 *   2. 兜底轮询 10 分钟一次，且只在「连着 WiFi 但未联网」时才真正发请求；
 *   3. 认证请求带 15 秒节流，避免网络抖动时连环打网关；
 *   4. 全部走原生线程，不启动 Dart 虚拟机；
 *   5. START_STICKY + 开机自启，被杀了系统会拉回来。
 */
class WifiAuthService : Service() {

    companion object {
        private const val TAG = "WifiAuth"
        private const val CHANNEL_ID = "haut_wifi_guard"
        private const val NOTIF_ID = 4101

        @Volatile
        var running: Boolean = false
            private set

        @Volatile
        var lastStatus: String = "未启动"
            private set

        @Volatile
        var lastOk: Boolean = false
            private set

        fun start(ctx: Context) {
            val i = Intent(ctx, WifiAuthService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, WifiAuthService::class.java))
        }
    }

    private var config: AuthConfig? = null
    private var cm: ConnectivityManager? = null
    private var wifiNetwork: Network? = null
    private val handler = Handler(Looper.getMainLooper())
    private var lastAttemptAt = 0L
    private var authing = false

    private val periodic = object : Runnable {
        override fun run() {
            checkIfAuthNeeded("定时检查")
            handler.postDelayed(this, 10 * 60 * 1000L)
        }
    }

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
            if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return
            wifiNetwork = network
            val validated = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            if (!validated) {
                notify("校园 WiFi 未认证，正在登录…")
                tryAuth("网络未验证")
            } else {
                notify("已联网 · ${clock()}")
            }
        }

        override fun onAvailable(network: Network) {
            wifiNetwork = network
        }

        override fun onLost(network: Network) {
            if (wifiNetwork == network) wifiNetwork = null
            notify("未连接 WiFi")
        }
    }

    override fun onCreate() {
        super.onCreate()
        config = AuthConfig(this)
        cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        // 每次启动都重新读一遍配置：用户在设置页改了密码要立刻生效
        config = AuthConfig(this)
        val cfg = config
        if (cfg == null || !cfg.enabled || !cfg.ready) {
            notify(if (cfg?.ready == false) "账号未配置" else "自动认证已关闭")
            stopSelf()
            return START_NOT_STICKY
        }

        if (!running) {
            running = true
            registerNetworkWatch()
            handler.postDelayed(periodic, 10 * 60 * 1000L)
            // 启动即检查一次，不用等到网络变化
            handler.postDelayed({ checkIfAuthNeeded("启动检查") }, 1500)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        lastStatus = "已停止"
        handler.removeCallbacksAndMessages(null)
        runCatching { cm?.unregisterNetworkCallback(callback) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ---------------------------------------------------------------- 内部
    private fun registerNetworkWatch() {
        val req = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        runCatching { cm?.registerNetworkCallback(req, callback) }
            .onFailure { Log.w(TAG, "注册网络监听失败: ${it.message}") }
    }

    private fun checkIfAuthNeeded(reason: String) {
        val caps = cm?.activeNetwork?.let { cm?.getNetworkCapabilities(it) } ?: return
        if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return
        if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) return
        tryAuth(reason)
    }

    private fun tryAuth(reason: String) {
        val cfg = config ?: return
        if (authing) return
        val now = System.currentTimeMillis()
        if (now - lastAttemptAt < 15_000L) return
        lastAttemptAt = now
        authing = true
        Log.i(TAG, "开始认证（$reason）")

        Thread {
            val net = wifiNetwork ?: cm?.let { PortalProbe.wifiNetwork(it) }
            // 网关先识别一遍：每个校区/楼栋 IP 段都不一样
            val gw = if (cfg.autoDiscover) {
                PortalProbe.discover(
                    cm ?: return@Thread,
                    net,
                    cfg.host,
                    cfg.port,
                    cfg.acId,
                )
            } else {
                PortalProbe.Gateway(cfg.host, cfg.port, cfg.acId)
            }
            if (cfg.autoDiscover) {
                cfg.host = gw.host
                cfg.port = gw.port
                gw.acId?.let { cfg.acId = it }
            }

            val r = SrunAuth.login(gw.host, gw.port, gw.acId ?: cfg.acId, cfg.user, cfg.pass, net)
            handler.post {
                authing = false
                lastOk = r.ok
                lastStatus = "${r.message} · ${clock()}"
                notify(if (r.ok) "已认证 · ${clock()}" else "${r.message}（网关 ${gw.host}:${gw.port}）")
                Log.i(TAG, "${r.message} @ ${gw.host}:${gw.port}")
            }
        }.apply { isDaemon = true }.start()
    }

    private fun startAsForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "校园网守护",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "连接校园 WiFi 时自动完成认证"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            nm.createNotificationChannel(ch)
        }
        val n = buildNotification("守护中 · 等待连接校园 WiFi")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun buildNotification(text: String): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("校园网自动认证")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_haut)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .build()
    }

    private fun notify(text: String) {
        runCatching {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID, buildNotification(text))
        }
    }

    private fun clock(): String =
        SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
}
