package cn.edu.haut.hautbox

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.util.Log
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URL

/**
 * 认证网关自动识别。
 *
 * 为什么必须做这件事：校园网 IP 段每个校区/每栋楼都不一样，
 * 写死一个 IP 换个地方就废。这里用三种手段依次尝试：
 *   1. 打系统探针地址（generate_204），看它 302 跳到哪 —— 那个 host 就是认证网关；
 *      跳转 URL 里通常还带 ac_id，一并抠出来；
 *   2. 拿链路默认网关，试 69 / 80 / 8080 三个端口；
 *   3. 都失败才用用户手填的地址兜底。
 *
 * 所有请求都绑定在 WiFi 网络上发 —— 手机上 5G 和 WiFi 同时在线时，
 * 不绑定就会走移动数据去打内网 IP，必然超时。
 */
object PortalProbe {

    private const val TAG = "PortalProbe"

    data class Gateway(val host: String, val port: String, val acId: String?)

    private val PROBES = listOf(
        "http://connect.rom.miui.com/generate_204",
        "http://connectivitycheck.platform.hicloud.com/generate_204",
        "http://www.gstatic.com/generate_204",
        "http://connect.rom.miui.com/generate_204",
    )

    /** 找到当前承载流量的 WiFi 网络（而不是默认的移动数据） */
    fun wifiNetwork(cm: ConnectivityManager): Network? {
        for (n in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(n) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return n
        }
        return null
    }

    fun discover(
        cm: ConnectivityManager,
        network: Network?,
        fallbackHost: String,
        fallbackPort: String,
        fallbackAcId: String,
    ): Gateway {
        // 1) 探针重定向
        for (p in PROBES) {
            val loc = redirectTarget(network, p)
            if (loc != null) {
                val gw = parse(loc)
                if (gw != null) {
                    Log.i(TAG, "由探针识别到网关 ${gw.host}:${gw.port} ac_id=${gw.acId}")
                    return gw
                }
            }
        }

        // 2) 默认网关 + 常见端口
        val gwHost = network?.let { defaultGateway(cm, it) }
        if (gwHost != null) {
            for (port in listOf("69", "80", "8080")) {
                if (reachable(network, gwHost, port)) {
                    Log.i(TAG, "由默认网关识别到 $gwHost:$port")
                    return Gateway(gwHost, port, null)
                }
            }
        }

        Log.w(TAG, "自动识别失败，用配置兜底 $fallbackHost:$fallbackPort")
        return Gateway(fallbackHost, fallbackPort, fallbackAcId)
    }

    // ---------------------------------------------------------------- 内部
    private fun redirectTarget(network: Network?, probe: String): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(probe)
            conn = (if (network != null) network.openConnection(url) else url.openConnection())
                as HttpURLConnection
            conn.instanceFollowRedirects = false
            conn.connectTimeout = 3000
            conn.readTimeout = 3000
            conn.requestMethod = "GET"
            conn.useCaches = false
            val code = conn.responseCode
            if (code in 300..399) {
                val loc = conn.getHeaderField("Location")
                if (!loc.isNullOrBlank()) return loc
            }
            null
        } catch (e: Exception) {
            null
        } finally {
            runCatching { conn?.disconnect() }
        }
    }

    /** 从跳转 URL 里抠 host / port / ac_id */
    private fun parse(location: String): Gateway? {
        val uri = runCatching { Uri.parse(location) }.getOrNull() ?: return null
        val host = uri.host ?: return null
        if (host.isBlank()) return null
        val port = if (uri.port > 0) uri.port.toString() else "80"
        val acId = runCatching { uri.getQueryParameter("ac_id") }.getOrNull()
        return Gateway(host, port, acId)
    }

    private fun defaultGateway(cm: ConnectivityManager, network: Network): String? {
        val lp: LinkProperties = runCatching { cm.getLinkProperties(network) }.getOrNull() ?: return null
        for (route in lp.routes) {
            if (route.isDefaultRoute && route.gateway != null) {
                return route.gateway?.hostAddress
            }
        }
        return null
    }

    private fun reachable(network: Network?, host: String, port: String): Boolean {
        return try {
            val p = port.toIntOrNull() ?: return false
            Socket().use { s ->
                if (network != null) network.bindSocket(s)
                s.connect(InetSocketAddress(host, p), 1200)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** 拿到认证网页地址，识别不出来就给空，让界面自己退回浏览器 */
    fun portalPage(context: Context, gateway: Gateway): String =
        "http://${gateway.host}:${gateway.port}/srun_portal_pc?ac_id=${gateway.acId ?: "1"}&theme=pro"
}
