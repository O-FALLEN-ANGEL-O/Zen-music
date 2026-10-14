package com.zen.music.zenmusic

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Lock-screen player.
 *
 * When enabled and music is playing, turning the screen off re-launches
 * MainActivity flagged to show over the keyguard; Dart then pushes the
 * full-screen lock-screen player route. "Unlock" asks the system to
 * dismiss the keyguard (PIN/fingerprint if the phone is secured) and
 * drops the show-when-locked flag again, so the rest of the app is never
 * reachable without unlocking.
 *
 * Android blocks background activity starts, so the launch on screen-off
 * needs the "Display over other apps" permission — Dart asks for it when
 * the user switches the feature on.
 */
object LockScreenPlugin {
    const val EXTRA = "zen_lockscreen"

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var receiver: BroadcastReceiver? = null
    private var enabled = false
    private var playing = false
    private var pendingShow = false

    fun register(engine: FlutterEngine, act: Activity) {
        activity = act
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, "zen/lockscreen")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    enabled = call.arguments as? Boolean ?: false
                    updateReceiver(act.applicationContext)
                    result.success(null)
                }
                "setPlaying" -> {
                    playing = call.arguments as? Boolean ?: false
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(canDrawOverlays(act))
                "requestOverlay" -> {
                    try {
                        act.startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:${act.packageName}")
                            )
                        )
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                "unlock" -> {
                    unlock(act)
                    result.success(null)
                }
                "consumePending" -> {
                    // Dart asks on startup whether a lock-screen launch
                    // arrived before its handler was ready.
                    val p = pendingShow
                    pendingShow = false
                    result.success(p)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canDrawOverlays(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(ctx)

    private fun updateReceiver(app: Context) {
        receiver?.let {
            try {
                app.unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        receiver = null
        if (!enabled) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != Intent.ACTION_SCREEN_OFF) return
                if (!enabled || !playing) return
                launch(app)
            }
        }
        receiver = r
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        if (Build.VERSION.SDK_INT >= 33) {
            app.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            app.registerReceiver(r, filter)
        }
    }

    private fun launch(app: Context) {
        try {
            val i = Intent(app, MainActivity::class.java).apply {
                putExtra(EXTRA, true)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
            }
            app.startActivity(i)
        } catch (_: Exception) {
            // Background start refused (no overlay permission) — the
            // system media controls still work.
        }
    }

    /** Called from MainActivity.onCreate / onNewIntent. */
    fun handleIntent(act: Activity, intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA, false) != true) return
        intent.removeExtra(EXTRA)
        setShowWhenLocked(act, true)
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("show", null)
        } else {
            pendingShow = true
        }
    }

    private fun setShowWhenLocked(act: Activity, on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            act.setShowWhenLocked(on)
        } else {
            @Suppress("DEPRECATION")
            if (on) {
                act.window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            } else {
                act.window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            }
        }
    }

    private fun unlock(act: Activity) {
        val km = act.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && km != null && km.isKeyguardLocked) {
            km.requestDismissKeyguard(act, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() {
                    setShowWhenLocked(act, false)
                    channel?.invokeMethod("unlocked", null)
                }

                override fun onDismissCancelled() {}
                override fun onDismissError() {}
            })
        } else {
            setShowWhenLocked(act, false)
            channel?.invokeMethod("unlocked", null)
        }
    }
}
