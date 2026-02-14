package com.example.mic_to_bluetooth

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mic_to_bluetooth/audio"
    private lateinit var audioManager: AudioManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "routeToBluetooth" -> {
                    val success = routeAudioToBluetooth()
                    result.success(success)
                }
                "routeToSpeaker" -> {
                    val success = routeAudioToSpeaker()
                    result.success(success)
                }
                "isBluetoothAudioConnected" -> {
                    val connected = isBluetoothAudioConnected()
                    result.success(connected)
                }
                "startBluetoothSco" -> {
                    val success = startBluetoothSco()
                    result.success(success)
                }
                "stopBluetoothSco" -> {
                    stopBluetoothSco()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun routeAudioToBluetooth(): Boolean {
        return try {
            // Enable Bluetooth SCO for bidirectional audio (mic + speaker)
            if (audioManager.isBluetoothScoAvailableOffCall) {
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
            }

            // Also try A2DP for better audio quality
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ - use setCommunicationDevice
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                val bluetoothDevice = devices.firstOrNull { device ->
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
                }
                bluetoothDevice?.let {
                    audioManager.setCommunicationDevice(it)
                }
            } else {
                // Older Android versions
                @Suppress("DEPRECATION")
                audioManager.isSpeakerphoneOn = false
                @Suppress("DEPRECATION")
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun routeAudioToSpeaker(): Boolean {
        return try {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                audioManager.clearCommunicationDevice()
            } else {
                @Suppress("DEPRECATION")
                audioManager.isSpeakerphoneOn = true
                @Suppress("DEPRECATION")
                audioManager.mode = AudioManager.MODE_NORMAL
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isBluetoothAudioConnected(): Boolean {
        return try {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            devices.any { device ->
                device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun startBluetoothSco(): Boolean {
        return try {
            if (audioManager.isBluetoothScoAvailableOffCall) {
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun stopBluetoothSco() {
        try {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        // Clean up audio routing when app is destroyed
        try {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                audioManager.clearCommunicationDevice()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }
}
