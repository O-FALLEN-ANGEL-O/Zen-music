package com.zen.music.zenmusic

import android.annotation.SuppressLint
import android.app.UiModeManager
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.os.Build
import androidx.car.app.connection.CarConnection
import androidx.lifecycle.Observer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * Streams "are we in a car?" signals to Dart on `zen/car`:
 *
 *  - Android Auto (phone projection) and Android Automotive, via
 *    androidx.car.app's CarConnection.
 *  - System car mode (UiModeManager), which some head units / docks set.
 *  - Bluetooth devices connecting/disconnecting, with a flag for the
 *    "car audio" / hands-free device classes. Dart also matches device
 *    names the user marked as their car, since many stereos report a
 *    generic class.
 *
 * Each event is a map: {kind, connected, name?, isCarClass?}.
 *
 * Receivers live on the application context for the same leak reasons
 * documented on MainActivity's zen/audio_device stream.
 */
object CarConnectionPlugin {
    private var sink: EventChannel.EventSink? = null
    private var btReceiver: BroadcastReceiver? = null
    private var carConnection: CarConnection? = null
    private var carObserver: Observer<Int>? = null

    fun register(engine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        EventChannel(engine.dartExecutor.binaryMessenger, "zen/car")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    teardown(app)
                    startAndroidAuto(app)
                    startBluetooth(app)
                    pushCarMode(app)
                }

                override fun onCancel(args: Any?) {
                    teardown(app)
                    sink = null
                }
            })
    }

    private fun emit(map: Map<String, Any?>) {
        try {
            sink?.success(map)
        } catch (_: Exception) {
        }
    }

    private fun startAndroidAuto(app: Context) {
        try {
            val conn = CarConnection(app)
            val obs = Observer<Int> { type ->
                val connected = type == CarConnection.CONNECTION_TYPE_PROJECTION ||
                    type == CarConnection.CONNECTION_TYPE_NATIVE
                emit(
                    mapOf(
                        "kind" to if (type == CarConnection.CONNECTION_TYPE_NATIVE)
                            "automotive" else "android_auto",
                        "connected" to connected,
                    )
                )
            }
            conn.type.observeForever(obs)
            carConnection = conn
            carObserver = obs
        } catch (_: Throwable) {
            // car-app library unavailable on this device — Bluetooth
            // detection still works.
        }
    }

    private fun pushCarMode(app: Context) {
        val ui = app.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager ?: return
        if (ui.currentModeType == Configuration.UI_MODE_TYPE_CAR) {
            emit(mapOf("kind" to "car_mode", "connected" to true))
        }
    }

    @SuppressLint("MissingPermission")
    private fun startBluetooth(app: Context) {
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(UiModeManager.ACTION_ENTER_CAR_MODE)
            addAction(UiModeManager.ACTION_EXIT_CAR_MODE)
        }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    UiModeManager.ACTION_ENTER_CAR_MODE ->
                        emit(mapOf("kind" to "car_mode", "connected" to true))
                    UiModeManager.ACTION_EXIT_CAR_MODE ->
                        emit(mapOf("kind" to "car_mode", "connected" to false))
                    BluetoothDevice.ACTION_ACL_CONNECTED,
                    BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                        val device: BluetoothDevice? =
                            if (Build.VERSION.SDK_INT >= 33) {
                                intent.getParcelableExtra(
                                    BluetoothDevice.EXTRA_DEVICE,
                                    BluetoothDevice::class.java
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                            }
                        var name: String? = null
                        var isCar = false
                        try {
                            name = device?.name
                            val cls = device?.bluetoothClass?.deviceClass
                            isCar = cls == BluetoothClass.Device.AUDIO_VIDEO_CAR_AUDIO ||
                                cls == BluetoothClass.Device.AUDIO_VIDEO_HANDSFREE
                        } catch (_: SecurityException) {
                            // BLUETOOTH_CONNECT not granted yet.
                        }
                        emit(
                            mapOf(
                                "kind" to "bluetooth",
                                "connected" to
                                    (intent.action == BluetoothDevice.ACTION_ACL_CONNECTED),
                                "name" to name,
                                "isCarClass" to isCar,
                            )
                        )
                    }
                }
            }
        }
        btReceiver = receiver
        if (Build.VERSION.SDK_INT >= 33) {
            app.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            app.registerReceiver(receiver, filter)
        }
    }

    private fun teardown(app: Context) {
        btReceiver?.let {
            try {
                app.unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        btReceiver = null
        val obs = carObserver
        val conn = carConnection
        if (obs != null && conn != null) {
            try {
                conn.type.removeObserver(obs)
            } catch (_: Exception) {
            }
        }
        carObserver = null
        carConnection = null
    }
}
