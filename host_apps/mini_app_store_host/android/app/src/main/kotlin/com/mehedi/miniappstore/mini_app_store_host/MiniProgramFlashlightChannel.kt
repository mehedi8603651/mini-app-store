package com.mehedi.miniappstore.mini_app_store_host

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Host-owned CameraManager torch adapter. */
internal class MiniProgramFlashlightChannel :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener,
    DefaultLifecycleObserver {
    companion object {
        private const val CHANNEL_NAME = "mini_program/flashlight"
        private const val CAMERA_PERMISSION_REQUEST = 4103
        private const val PREFS_NAME = "mini_program_flashlight"
        private const val PREF_PERMISSION_REQUESTED = "camera_permission_requested"

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramFlashlightChannel())
        }
    }

    private var applicationContext: Context? = null
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var cameraManager: CameraManager? = null
    private var torchCameraId: String? = null
    private var torchAvailable = false
    private var torchEnabled = false
    private var pendingEnable: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val torchCallback = object : CameraManager.TorchCallback() {
        override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
            if (cameraId == torchCameraId) {
                torchAvailable = true
                torchEnabled = enabled
            }
        }

        override fun onTorchModeUnavailable(cameraId: String) {
            if (cameraId == torchCameraId) {
                torchAvailable = false
                torchEnabled = false
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        cameraManager = binding.applicationContext
            .getSystemService(Context.CAMERA_SERVICE) as CameraManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                torchCameraId = findTorchCamera(cameraManager!!)
                torchAvailable = torchCameraId != null
                cameraManager?.registerTorchCallback(torchCallback, mainHandler)
            } catch (_: Exception) {
                torchAvailable = false
            }
        }
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleCall)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        turnOffBestEffort()
        pendingEnable?.error(
            "flashlight_unavailable",
            "The flashlight provider detached from the Flutter engine.",
            null,
        )
        pendingEnable = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            cameraManager?.unregisterTorchCallback(torchCallback)
        }
        channel?.setMethodCallHandler(null)
        channel = null
        cameraManager = null
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach(false)

    override fun onDetachedFromActivity() = detach(true)

    override fun onStop(owner: LifecycleOwner) {
        turnOffBestEffort()
    }

    private fun attach(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        (binding.activity as? LifecycleOwner)?.lifecycle?.addObserver(this)
    }

    private fun detach(permanent: Boolean) {
        turnOffBestEffort()
        if (permanent) {
            pendingEnable?.error(
                "flashlight_unavailable",
                "The flashlight permission request stopped because the host activity detached.",
                null,
            )
            pendingEnable = null
        }
        val current = activity
        if (current is LifecycleOwner) current.lifecycle.removeObserver(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(statusMap())
            "setEnabled" -> {
                val enabled = (call.arguments as? Map<*, *>)?.get("enabled") as? Boolean
                if (enabled == null) {
                    result.error(
                        "flashlight_operation_failed",
                        "Flashlight enabled must be a boolean.",
                        null,
                    )
                } else if (enabled) {
                    requestEnable(result)
                } else {
                    setTorch(false, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun requestEnable(result: MethodChannel.Result) {
        if (!isSupported()) {
            result.error(
                "flashlight_unavailable",
                "This Android device has no available flashlight.",
                null,
            )
            return
        }
        if (pendingEnable != null) {
            result.error(
                "flashlight_in_use",
                "A flashlight permission request is already in progress.",
                null,
            )
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "flashlight_unavailable",
                "Flashlight control requires a foreground Android activity.",
                null,
            )
            return
        }
        if (hasCameraPermission()) {
            setTorch(true, result)
            return
        }
        val preferences = currentActivity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val previouslyRequested = preferences.getBoolean(PREF_PERMISSION_REQUESTED, false)
        if (previouslyRequested &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                currentActivity,
                Manifest.permission.CAMERA,
            )
        ) {
            result.error(
                "flashlight_permission_denied_permanently",
                "Camera permission for flashlight control is permanently denied.",
                null,
            )
            return
        }
        pendingEnable = result
        preferences.edit().putBoolean(PREF_PERMISSION_REQUESTED, true).apply()
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != CAMERA_PERMISSION_REQUEST) return false
        val pending = pendingEnable ?: return false
        pendingEnable = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            setTorch(true, pending)
            return true
        }
        val currentActivity = activity
        val permanentlyDenied = currentActivity != null &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                currentActivity,
                Manifest.permission.CAMERA,
            )
        pending.error(
            if (permanentlyDenied) {
                "flashlight_permission_denied_permanently"
            } else {
                "flashlight_permission_denied"
            },
            if (permanentlyDenied) {
                "Camera permission for flashlight control is permanently denied."
            } else {
                "Camera permission for flashlight control was denied."
            },
            null,
        )
        return true
    }

    private fun setTorch(enabled: Boolean, result: MethodChannel.Result) {
        if (enabled && !hasCameraPermission()) {
            result.error(
                "flashlight_permission_denied",
                "Camera permission for flashlight control was denied.",
                null,
            )
            return
        }
        val manager = cameraManager
        val cameraId = torchCameraId
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || manager == null || cameraId == null) {
            result.error(
                "flashlight_unavailable",
                "This Android device has no available flashlight.",
                null,
            )
            return
        }
        try {
            manager.setTorchMode(cameraId, enabled)
            torchAvailable = true
            torchEnabled = enabled
            result.success(statusMap())
        } catch (error: CameraAccessException) {
            result.error(
                if (error.reason == CameraAccessException.CAMERA_IN_USE ||
                    error.reason == CameraAccessException.MAX_CAMERAS_IN_USE
                ) {
                    "flashlight_in_use"
                } else {
                    "flashlight_operation_failed"
                },
                "Android could not change the flashlight state.",
                null,
            )
        } catch (_: SecurityException) {
            result.error(
                "flashlight_permission_denied",
                "Camera permission for flashlight control was denied.",
                null,
            )
        } catch (_: Exception) {
            result.error(
                "flashlight_operation_failed",
                "Android could not change the flashlight state.",
                null,
            )
        }
    }

    private fun turnOffBestEffort() {
        if (!torchEnabled || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val manager = cameraManager
            val cameraId = torchCameraId
            if (manager != null && cameraId != null) manager.setTorchMode(cameraId, false)
        } catch (_: Exception) {
            // Foreground cleanup is best effort.
        }
        torchEnabled = false
    }

    private fun hasCameraPermission(): Boolean {
        val context = activity ?: applicationContext ?: return false
        return ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            torchCameraId != null &&
            torchAvailable

    private fun statusMap(): Map<String, Boolean> = mapOf(
        "available" to isSupported(),
        "enabled" to (isSupported() && torchEnabled),
    )

    private fun findTorchCamera(manager: CameraManager): String? {
        var fallback: String? = null
        for (cameraId in manager.cameraIdList) {
            val characteristics = manager.getCameraCharacteristics(cameraId)
            if (characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) != true) continue
            fallback = fallback ?: cameraId
            if (characteristics.get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_BACK
            ) {
                return cameraId
            }
        }
        return fallback
    }
}
