package com.mehedi.miniappstore.mini_app_store_host

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Host-owned system-camera channel created by
 * `miniprogram host capability init camera`.
 *
 * Captured files remain in the host cache. Flutter receives only an opaque
 * media reference and metadata, never a path or content URI.
 */
internal class MiniProgramCameraChannel : FlutterPlugin, ActivityAware {
    companion object {
        private const val CHANNEL_NAME = "mini_program/camera"
        private const val FILE_PROVIDER_SUFFIX = ".mini_program_camera_files"

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramCameraChannel())
        }
    }

    private data class PendingCapture(
        val captureId: String,
        val miniProgramId: String,
        val file: File,
        val uri: Uri,
        val quality: Int,
        val maxWidth: Int?,
        val maxHeight: Int?,
        val result: MethodChannel.Result,
        var cancelled: Boolean = false,
    )

    private var channel: MethodChannel? = null
    private var activity: ComponentActivity? = null
    private var launcher: ActivityResultLauncher<Uri>? = null
    private var pending: PendingCapture? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleCall)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        failPending(
            "camera_unavailable",
            "The camera provider detached from the Flutter engine.",
        )
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detach("Photo capture stopped while Android configuration changed.")
    }

    override fun onDetachedFromActivity() {
        detach("Photo capture stopped because the host activity detached.")
    }

    private fun attach(binding: ActivityPluginBinding) {
        val componentActivity = binding.activity as? ComponentActivity
        if (componentActivity == null) {
            activity = null
            return
        }
        activity = componentActivity
        launcher?.unregister()
        launcher = componentActivity.activityResultRegistry.register(
            "mini_program_camera_capture",
            ActivityResultContracts.TakePicture(),
            ::completeCapture,
        )
    }

    private fun detach(message: String) {
        if (pending != null) {
            failPending("camera_unavailable", message)
        }
        launcher?.unregister()
        launcher = null
        activity = null
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capturePhoto" -> capturePhoto(call, result)
            "cancel" -> cancel(call, result)
            "release" -> release(call, result)
            "loadPreview" -> loadPreview(call, result)
            "releaseMedia" -> releaseMedia(call, result)
            else -> result.notImplemented()
        }
    }

    private fun capturePhoto(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error(
                "camera_request_in_progress",
                "A photo capture request is already in progress.",
                null,
            )
            return
        }
        val currentActivity = activity
        val currentLauncher = launcher
        if (currentActivity == null || currentLauncher == null) {
            result.error(
                "camera_unavailable",
                "Android system-camera capture requires a foreground activity.",
                null,
            )
            return
        }
        val arguments = call.arguments as? Map<*, *>
        val captureId = arguments?.get("captureId") as? String
        val miniProgramId = arguments?.get("miniProgramId") as? String
        val quality = (arguments?.get("quality") as? Number)?.toInt()
        val maxWidth = (arguments?.get("maxWidth") as? Number)?.toInt()
        val maxHeight = (arguments?.get("maxHeight") as? Number)?.toInt()
        if (captureId.isNullOrBlank() || miniProgramId.isNullOrBlank() ||
            quality == null || quality !in 1..100 ||
            (maxWidth != null && maxWidth !in 64..8192) ||
            (maxHeight != null && maxHeight !in 64..8192)
        ) {
            result.error(
                "camera_invalid_result",
                "The camera request is invalid.",
                null,
            )
            return
        }

        val captureIntent = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE)
        if (captureIntent.resolveActivity(currentActivity.packageManager) == null) {
            result.error(
                "camera_unavailable",
                "No Android system camera is available.",
                null,
            )
            return
        }

        try {
            val directory = File(currentActivity.cacheDir, "mini_program_camera")
            if (!directory.exists() && !directory.mkdirs()) {
                throw IllegalStateException("Could not create camera cache directory.")
            }
            val file = File(directory, "photo_${UUID.randomUUID()}.jpg")
            val uri = FileProvider.getUriForFile(
                currentActivity,
                currentActivity.packageName + FILE_PROVIDER_SUFFIX,
                file,
            )
            currentActivity.packageManager
                .queryIntentActivities(captureIntent, 0)
                .forEach { resolved ->
                    currentActivity.grantUriPermission(
                        resolved.activityInfo.packageName,
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    )
                }
            pending = PendingCapture(
                captureId = captureId,
                miniProgramId = miniProgramId,
                file = file,
                uri = uri,
                quality = quality,
                maxWidth = maxWidth,
                maxHeight = maxHeight,
                result = result,
            )
            currentLauncher.launch(uri)
        } catch (_: Exception) {
            pending = null
            result.error(
                "camera_storage_unavailable",
                "The host could not prepare private camera storage.",
                null,
            )
        }
    }

    private fun completeCapture(success: Boolean) {
        val request = pending ?: return
        pending = null
        revoke(request.uri)
        if (request.cancelled || !success) {
            request.file.delete()
            request.result.error(
                "camera_capture_cancelled",
                "Photo capture was cancelled.",
                null,
            )
            return
        }
        try {
            resizeIfRequested(request)
            val bounds = imageBounds(request.file)
            if (!request.file.exists() || request.file.length() <= 0L || bounds == null) {
                throw IllegalStateException("The system camera returned no valid image.")
            }
            val mediaRef = "camera_media_${UUID.randomUUID()}"
            val registered = MiniProgramHostMediaRegistry.register(
                MiniProgramHostMediaRegistry.Entry(
                    miniProgramId = request.miniProgramId,
                    mediaRef = mediaRef,
                    file = request.file,
                    uri = request.uri,
                    fileName = request.file.name,
                    mimeType = "image/jpeg",
                ),
            )
            if (!registered) {
                throw IllegalStateException("Could not register captured media.")
            }
            request.result.success(
                mapOf(
                    "captureId" to request.captureId,
                    "mediaRef" to mediaRef,
                    "fileName" to request.file.name,
                    "mimeType" to "image/jpeg",
                    "bytes" to request.file.length(),
                    "width" to bounds.first,
                    "height" to bounds.second,
                    "capturedAtUtc" to utcNow(),
                    "source" to "camera",
                ),
            )
        } catch (_: Exception) {
            request.file.delete()
            request.result.error(
                "camera_invalid_result",
                "The system camera returned an invalid photo.",
                null,
            )
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val captureId = (call.arguments as? Map<*, *>)?.get("captureId") as? String
        val request = pending
        if (request == null || request.captureId != captureId) {
            result.success(false)
            return
        }
        // Android cannot reliably close another app's camera activity. Marking
        // the request cancelled guarantees its eventual output is discarded.
        request.cancelled = true
        result.success(true)
    }

    private fun release(call: MethodCall, result: MethodChannel.Result) {
        val mediaRef = (call.arguments as? Map<*, *>)?.get("mediaRef") as? String
        if (mediaRef.isNullOrBlank()) {
            result.error("camera_invalid_result", "mediaRef is required.", null)
            return
        }
        MiniProgramHostMediaRegistry.releaseAny(mediaRef)
        result.success(null)
    }

    private fun loadPreview(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val miniProgramId = arguments?.get("miniProgramId") as? String
        val mediaRef = arguments?.get("mediaRef") as? String
        val maxBytes = (arguments?.get("maxBytes") as? Number)?.toLong()
        if (miniProgramId.isNullOrBlank() ||
            mediaRef.isNullOrBlank() ||
            maxBytes == null || maxBytes <= 0L
        ) {
            result.error("media_invalid_result", "The media preview request is invalid.", null)
            return
        }
        val existing = MiniProgramHostMediaRegistry.find(mediaRef)
        if (existing == null) {
            result.error("media_not_found", "The temporary media is no longer available.", null)
            return
        }
        val entry = MiniProgramHostMediaRegistry.findOwned(miniProgramId, mediaRef)
        if (entry == null) {
            result.error("media_not_owned", "The media reference belongs to another mini-program.", null)
            return
        }
        if (!entry.mimeType.startsWith("image/") || entry.size > maxBytes) {
            result.error("media_preview_too_large", "The media cannot be loaded as a bounded image preview.", null)
            return
        }
        try {
            result.success(
                mapOf(
                    "mediaRef" to entry.mediaRef,
                    "mimeType" to entry.mimeType,
                    "bytes" to entry.file.readBytes(),
                ),
            )
        } catch (_: Exception) {
            result.error("media_unavailable", "The host could not read the temporary media.", null)
        }
    }

    private fun releaseMedia(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val miniProgramId = arguments?.get("miniProgramId") as? String
        val mediaRef = arguments?.get("mediaRef") as? String
        if (miniProgramId.isNullOrBlank() || mediaRef.isNullOrBlank()) {
            result.error("media_invalid_result", "The media release request is invalid.", null)
            return
        }
        val existing = MiniProgramHostMediaRegistry.find(mediaRef)
        if (existing != null && existing.miniProgramId != miniProgramId) {
            result.error("media_not_owned", "The media reference belongs to another mini-program.", null)
            return
        }
        result.success(MiniProgramHostMediaRegistry.releaseOwned(miniProgramId, mediaRef))
    }

    private fun resizeIfRequested(request: PendingCapture) {
        val bounds = imageBounds(request.file) ?: return
        val maxWidth = request.maxWidth ?: bounds.first
        val maxHeight = request.maxHeight ?: bounds.second
        val scale = min(
            1.0,
            min(maxWidth.toDouble() / bounds.first, maxHeight.toDouble() / bounds.second),
        )
        if (scale >= 1.0) return

        val targetWidth = (bounds.first * scale).roundToInt().coerceAtLeast(1)
        val targetHeight = (bounds.second * scale).roundToInt().coerceAtLeast(1)

        val options = BitmapFactory.Options().apply {
            var sample = 1
            while (bounds.first / (sample * 2) >= targetWidth &&
                bounds.second / (sample * 2) >= targetHeight
            ) {
                sample *= 2
            }
            inSampleSize = sample
        }
        val decoded = BitmapFactory.decodeFile(request.file.path, options)
            ?: throw IllegalStateException("Could not decode captured photo.")
        val scaled = Bitmap.createScaledBitmap(decoded, targetWidth, targetHeight, true)
        val replacement = File(request.file.parentFile, request.file.name + ".tmp")
        FileOutputStream(replacement).use { output ->
            if (!scaled.compress(Bitmap.CompressFormat.JPEG, request.quality, output)) {
                throw IllegalStateException("Could not encode captured photo.")
            }
        }
        if (scaled !== decoded) scaled.recycle()
        decoded.recycle()
        if (!replacement.renameTo(request.file)) {
            replacement.copyTo(request.file, overwrite = true)
            replacement.delete()
        }
    }

    private fun imageBounds(file: File): Pair<Int, Int>? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, options)
        return if (options.outWidth > 0 && options.outHeight > 0) {
            Pair(options.outWidth, options.outHeight)
        } else {
            null
        }
    }

    private fun failPending(code: String, message: String) {
        val request = pending ?: return
        pending = null
        revoke(request.uri)
        request.file.delete()
        request.result.error(code, message, null)
    }

    private fun revoke(uri: Uri) {
        activity?.revokeUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
    }

    private fun utcNow(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date())
    }
}
