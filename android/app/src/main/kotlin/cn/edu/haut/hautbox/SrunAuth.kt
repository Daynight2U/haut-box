package cn.edu.haut.hautbox

import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * 深澜 srun（Srun3k）认证，原生实现。
 *
 * 放原生而不是 Flutter 的原因：后台服务要能在 App 进程被回收后继续跑，
 * 不能依赖 Dart 虚拟机。
 *
 * 加密规则与学校客户端一致：
 *   - 用户名：每个字节 +4，前缀 "{SRUN3}\r\n"
 *   - 密码：与 "1234567890" 逆序逐位 XOR，低 4 位 +0x36、高 4 位 +0x63，按奇偶交替拼接
 */
object SrunAuth {

    data class Result(val ok: Boolean, val message: String)

    fun encodeUsername(raw: String): String {
        val sb = StringBuilder("{SRUN3}\r\n")
        for (b in raw.toByteArray(Charsets.UTF_8)) {
            sb.append(((b.toInt() and 0xFF) + 4).toChar())
        }
        return sb.toString()
    }

    fun encodePassword(raw: String): String {
        val key = "1234567890"
        val sb = StringBuilder()
        val bytes = raw.toByteArray(Charsets.UTF_8)
        for (i in bytes.indices) {
            val k = (bytes[i].toInt() and 0xFF) xor key[9 - (i % 10)].code
            val lo = (k and 0x0f) + 0x36
            val hi = ((k shr 4) and 0x0f) + 0x63
            if (i % 2 == 0) {
                sb.append(lo.toChar())
                sb.append(hi.toChar())
            } else {
                sb.append(hi.toChar())
                sb.append(lo.toChar())
            }
        }
        return sb.toString()
    }

    /**
     * @param network 绑定的 WiFi 网络。手机同时开着 5G 时必须指定，
     *                否则请求会走移动数据去打内网 IP，直接超时。
     */
    fun login(
        host: String,
        port: String,
        acId: String,
        user: String,
        pass: String,
        network: android.net.Network? = null,
    ): Result {
        val endpoint = "http://$host:$port/cgi-bin/srun_portal"
        val form = listOf(
            "action" to "login",
            "n" to "117",
            "mbytes" to "0",
            "minutes" to "0",
            "ac_id" to acId,
            "mac" to "02:00:00:00:00:00",
            "type" to "3",
            "username" to encodeUsername(user),
            "password" to encodePassword(pass),
            "drop" to "0",
            "pop" to "1",
        ).joinToString("&") { "${enc(it.first)}=${enc(it.second)}" }

        var conn: HttpURLConnection? = null
        return try {
            val url = URL(endpoint)
            conn = (if (network != null) network.openConnection(url) else url.openConnection())
                as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 5000
            conn.readTimeout = 8000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
            conn.setRequestProperty("User-Agent", "HAUT-App/0.5 (Android)")
            conn.outputStream.use { it.write(form.toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            val text = (if (code in 200..299) conn.inputStream else conn.errorStream)
                ?.bufferedReader()?.use { it.readText() } ?: ""
            val ok = text.contains("\"error\":\"ok\"") ||
                text.contains("\"res\":\"ok\"") ||
                text.contains("login_ok")
            if (ok) {
                Result(true, "认证成功")
            } else {
                Result(false, "认证失败：${text.take(120).ifBlank { "HTTP $code" }}")
            }
        } catch (e: Exception) {
            Result(false, "连不上认证网关（${e.javaClass.simpleName}）")
        } finally {
            conn?.disconnect()
        }
    }

    private fun enc(s: String): String = URLEncoder.encode(s, "UTF-8")
}
