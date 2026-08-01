package com.mehedi.miniappstore.mini_app_store_host

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Host-owned QR scanner bridge installed by mini_program_tooling. */
internal class MiniProgramQrScannerChannel :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {
    companion object {
        private const val CHANNEL_NAME = "mini_program/qr_scanner"
        private const val SCAN_REQUEST_CODE = 4210
        private const val CAMERA_PERMISSION_REQUEST_CODE = 4211
        private const val PREFS_NAME = "mini_program_qr_scanner"
        private const val PREF_PERMISSION_REQUESTED = "camera_permission_requested"

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramQrScannerChannel())
        }
    }

    private data class ScanRequest(
        val scanId: String,
        val miniProgramId: String,
        val allowTorch: Boolean,
        val timeoutMs: Long,
        val result: MethodChannel.Result,
        var cancelled: Boolean = false,
    )

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pending: ScanRequest? = null
    private var waitingForPermission = false
    private var permissionHadBeenRequested = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleCall)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        failPending("qr_unavailable", "The QR scanner detached from the Flutter engine.")
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attach(binding)

    override fun onDetachedFromActivityForConfigChanges() {
        detach("QR scanning stopped while Android configuration changed.")
    }

    override fun onDetachedFromActivity() {
        detach("QR scanning stopped because the host activity detached.")
    }

    private fun attach(binding: ActivityPluginBinding) {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    private fun detach(message: String) {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
        failPending("qr_unavailable", message)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scan" -> scan(call, result)
            "cancel" -> cancel(call, result)
            else -> result.notImplemented()
        }
    }

    private fun scan(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error(
                "qr_request_in_progress",
                "A QR scan request is already in progress.",
                null,
            )
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "qr_unavailable",
                "QR scanning requires a foreground Android activity.",
                null,
            )
            return
        }
        val arguments = call.arguments as? Map<*, *>
        val scanId = arguments?.get("scanId") as? String
        val miniProgramId = arguments?.get("miniProgramId") as? String
        val allowTorch = arguments?.get("allowTorch") as? Boolean
        val timeoutMs = (arguments?.get("timeoutMs") as? Number)?.toLong()
        if (scanId.isNullOrBlank() || miniProgramId.isNullOrBlank() ||
            allowTorch == null || timeoutMs == null || timeoutMs !in 1_000L..120_000L
        ) {
            result.error("qr_invalid_result", "The QR scan request is invalid.", null)
            return
        }
        val request = ScanRequest(
            scanId = scanId,
            miniProgramId = miniProgramId,
            allowTorch = allowTorch,
            timeoutMs = timeoutMs,
            result = result,
        )
        pending = request
        if (ContextCompat.checkSelfPermission(
                currentActivity,
                Manifest.permission.CAMERA,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            launchScanner(request)
            return
        }
        val preferences = currentActivity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        permissionHadBeenRequested = preferences.getBoolean(
            PREF_PERMISSION_REQUESTED,
            false,
        )
        preferences.edit().putBoolean(PREF_PERMISSION_REQUESTED, true).apply()
        waitingForPermission = true
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST_CODE,
        )
    }

    private fun launchScanner(request: ScanRequest) {
        val currentActivity = activity
        if (currentActivity == null) {
            failPending(
                "qr_unavailable",
                "QR scanning requires a foreground Android activity.",
            )
            return
        }
        if (request.cancelled) {
            failPending("qr_scan_cancelled", "QR scanning was cancelled.")
            return
        }
        try {
            val intent = Intent(currentActivity, MiniProgramQrScannerActivity::class.java)
                .putExtra(MiniProgramQrScannerActivity.EXTRA_SCAN_ID, request.scanId)
                .putExtra(MiniProgramQrScannerActivity.EXTRA_ALLOW_TORCH, request.allowTorch)
                .putExtra(MiniProgramQrScannerActivity.EXTRA_TIMEOUT_MS, request.timeoutMs)
            currentActivity.startActivityForResult(intent, SCAN_REQUEST_CODE)
        } catch (_: Exception) {
            failPending(
                "qr_unavailable",
                "The Android QR scanner activity could not be opened.",
            )
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val scanId = (call.arguments as? Map<*, *>)?.get("scanId") as? String
        val request = pending
        if (scanId.isNullOrBlank() || request == null || request.scanId != scanId) {
            result.success(false)
            return
        }
        request.cancelled = true
        MiniProgramQrScannerActivity.cancel(scanId)
        if (waitingForPermission) {
            MiniProgramQrScannerActivity.clearPendingCancellation(scanId)
            failPending("qr_scan_cancelled", "QR scanning was cancelled.")
        }
        result.success(true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != CAMERA_PERMISSION_REQUEST_CODE) return false
        waitingForPermission = false
        val request = pending ?: return true
        if (request.cancelled) {
            failPending("qr_scan_cancelled", "QR scanning was cancelled.")
            return true
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            launchScanner(request)
            return true
        }
        val currentActivity = activity
        val permanentlyDenied = permissionHadBeenRequested &&
            currentActivity != null &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                currentActivity,
                Manifest.permission.CAMERA,
            )
        failPending(
            if (permanentlyDenied) {
                "qr_permission_denied_permanently"
            } else {
                "qr_permission_denied"
            },
            if (permanentlyDenied) {
                "Camera permission for QR scanning is permanently denied."
            } else {
                "Camera permission for QR scanning was denied."
            },
        )
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SCAN_REQUEST_CODE) return false
        val request = pending ?: return true
        pending = null
        waitingForPermission = false
        if (request.cancelled) {
            request.result.error("qr_scan_cancelled", "QR scanning was cancelled.", null)
            return true
        }
        if (resultCode != Activity.RESULT_OK) {
            request.result.error(
                data?.getStringExtra(MiniProgramQrScannerActivity.EXTRA_ERROR_CODE)
                    ?: "qr_scan_cancelled",
                data?.getStringExtra(MiniProgramQrScannerActivity.EXTRA_ERROR_MESSAGE)
                    ?: "QR scanning was cancelled.",
                null,
            )
            return true
        }
        val rawValue = data?.getStringExtra(MiniProgramQrScannerActivity.EXTRA_RAW_VALUE)
        val valueType = data?.getStringExtra(MiniProgramQrScannerActivity.EXTRA_VALUE_TYPE)
        val scannedAtUtc = data?.getStringExtra(
            MiniProgramQrScannerActivity.EXTRA_SCANNED_AT_UTC,
        )
        if (rawValue.isNullOrEmpty() || valueType.isNullOrBlank() ||
            scannedAtUtc.isNullOrBlank()
        ) {
            request.result.error(
                "qr_invalid_result",
                "Android returned an invalid QR scan result.",
                null,
            )
            return true
        }
        request.result.success(
            mapOf(
                "rawValue" to rawValue,
                "format" to "qr",
                "valueType" to valueType,
                "scannedAtUtc" to scannedAtUtc,
            ),
        )
        return true
    }

    private fun failPending(code: String, message: String) {
        val request = pending ?: return
        pending = null
        waitingForPermission = false
        request.result.error(code, message, null)
    }
}
