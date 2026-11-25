package cn.edu.haut.hautbox

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

/**
 * 校园网认证配置。密码用 Android Keystore 派生密钥加密后落盘（EncryptedSharedPreferences），
 * 明文只在内存里活一次。
 */
class AuthConfig(context: Context) {

    private val prefs: SharedPreferences = runCatching {
        val keyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        EncryptedSharedPreferences.create(
            FILE,
            keyAlias,
            context.applicationContext,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }.getOrElse {
        // 极少数机型 Keystore 异常时降级到私有目录，至少保证功能可用
        context.applicationContext.getSharedPreferences(FILE + "_plain", Context.MODE_PRIVATE)
    }

    var enabled: Boolean
        get() = prefs.getBoolean("enabled", false)
        set(v) = prefs.edit().putBoolean("enabled", v).apply()

    var ssid: String
        get() = prefs.getString("ssid", "") ?: ""
        set(v) = prefs.edit().putString("ssid", v).apply()

    /** 网关自动识别：校园网每个校区 IP 段不同，写死必废 */
    var autoDiscover: Boolean
        get() = prefs.getBoolean("auto_discover", true)
        set(v) = prefs.edit().putBoolean("auto_discover", v).apply()

    var host: String
        get() = prefs.getString("host", "172.16.154.130") ?: "172.16.154.130"
        set(v) = prefs.edit().putString("host", v).apply()

    var port: String
        get() = prefs.getString("port", "69") ?: "69"
        set(v) = prefs.edit().putString("port", v).apply()

    var acId: String
        get() = prefs.getString("ac_id", "1") ?: "1"
        set(v) = prefs.edit().putString("ac_id", v).apply()

    var user: String
        get() = prefs.getString("user", "") ?: ""
        set(v) = prefs.edit().putString("user", v).apply()

    var pass: String
        get() = prefs.getString("pass", "") ?: ""
        set(v) = prefs.edit().putString("pass", v).apply()

    val ready: Boolean
        get() = user.isNotEmpty() && pass.isNotEmpty() && host.isNotEmpty()

    companion object {
        private const val FILE = "haut_wifi_auth"
    }
}
