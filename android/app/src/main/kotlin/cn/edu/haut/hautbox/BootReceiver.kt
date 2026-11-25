package cn.edu.haut.hautbox

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 开机自启：只要用户开着自动认证，重启后服务自己回来 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val cfg = AuthConfig(context)
        if (cfg.enabled && cfg.ready) {
            WifiAuthService.start(context)
        }
    }
}
