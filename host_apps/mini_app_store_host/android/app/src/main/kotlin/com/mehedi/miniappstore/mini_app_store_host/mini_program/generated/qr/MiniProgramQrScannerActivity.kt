package com.mehedi.miniappstore.mini_app_store_host

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.lang.ref.WeakReference
import java.text.SimpleDateFormat
import java.util.Collections
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** CameraX and bundled ML Kit QR-only scanner owned by the host. */
internal class MiniProgramQrScannerActivity : ComponentActivity() {
    companion object {
        const val EXTRA_SCAN_ID = "scanId"
        const val EXTRA_ALLOW_TORCH = "allowTorch"
        const val EXTRA_TIMEOUT_MS = "timeoutMs"
        const val EXTRA_RAW_VALUE = "rawValue"
        const val EXTRA_VALUE_TYPE = "valueType"
        const val EXTRA_SCANNED_AT_UTC = "scannedAtUtc"
        const val EXTRA_ERROR_CODE = "errorCode"
        const val EXTRA_ERROR_MESSAGE = "errorMessage"

        private var active = WeakReference<MiniProgramQrScannerActivity>(null)
        private val cancelledBeforeStart = Collections.synchronizedSet(
            mutableSetOf<String>(),
        )

        fun cancel(scanId: String): Boolean {
            val current = active.get()
            if (current != null && current.scanId == scanId) {
                current.runOnUiThread {
                    current.finishWithError(
                        "qr_scan_cancelled",
                        "QR scanning was cancelled.",
                    )
                }
                return true
            }
            cancelledBeforeStart.add(scanId)
            return true
        }

        fun clearPendingCancellation(scanId: String) {
            cancelledBeforeStart.remove(scanId)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val analyzing = AtomicBoolean(false)
    private val completed = AtomicBoolean(false)
    private lateinit var scanner: BarcodeScanner
    private lateinit var previewView: PreviewView
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var torchButton: TextView? = null
    private var torchEnabled = false
    private var scanId = ""

    private val timeoutRunnable = Runnable {
        finishWithError("qr_timeout", "The QR scan request timed out.")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        scanId = intent.getStringExtra(EXTRA_SCAN_ID).orEmpty()
        val timeoutMs = intent.getLongExtra(EXTRA_TIMEOUT_MS, 60_000L)
        if (scanId.isBlank() || timeoutMs !in 1_000L..120_000L) {
            finishWithError("qr_invalid_result", "The QR scan request is invalid.")
            return
        }
        if (active.get() != null) {
            finishWithError(
                "qr_camera_in_use",
                "Another QR scanner is already using the camera.",
            )
            return
        }
        active = WeakReference(this)
        if (cancelledBeforeStart.remove(scanId)) {
            finishWithError("qr_scan_cancelled", "QR scanning was cancelled.")
            return
        }
        scanner = BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                .build(),
        )
        buildUserInterface(intent.getBooleanExtra(EXTRA_ALLOW_TORCH, false))
        mainHandler.postDelayed(timeoutRunnable, timeoutMs)
        startCamera()
    }

    private fun buildUserInterface(allowTorch: Boolean) {
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        previewView = PreviewView(this).apply {
            scaleType = PreviewView.ScaleType.FILL_CENTER
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        }
        root.addView(
            previewView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        root.addView(
            control("Close") {
                finishWithError("qr_scan_cancelled", "QR scanning was cancelled.")
            },
            controlLayout(Gravity.TOP or Gravity.START),
        )
        if (allowTorch) {
            torchButton = control("Light") { toggleTorch() }
            root.addView(torchButton, controlLayout(Gravity.TOP or Gravity.END))
        }
        val hint = TextView(this).apply {
            text = "Place a QR code inside the camera view"
            setTextColor(Color.WHITE)
            textSize = 17f
            gravity = Gravity.CENTER
            setPadding(32, 20, 32, 20)
            setBackgroundColor(0x99000000.toInt())
        }
        root.addView(
            hint,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ).apply { setMargins(32, 32, 32, 64) },
        )
        setContentView(root)
    }

    private fun control(label: String, onTap: () -> Unit): TextView =
        TextView(this).apply {
            text = label
            contentDescription = label
            setTextColor(Color.WHITE)
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(24, 16, 24, 16)
            setBackgroundColor(0x99000000.toInt())
            setOnClickListener { onTap() }
        }

    private fun controlLayout(gravity: Int) = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
        gravity,
    ).apply { setMargins(24, 32, 24, 24) }

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener(
            {
                if (completed.get()) return@addListener
                try {
                    val provider = future.get()
                    cameraProvider = provider
                    val preview = Preview.Builder().build().also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                    analysis.setAnalyzer(analysisExecutor, ::analyze)
                    provider.unbindAll()
                    camera = provider.bindToLifecycle(
                        this,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview,
                        analysis,
                    )
                    if (camera?.cameraInfo?.hasFlashUnit() != true) {
                        torchButton?.visibility = android.view.View.GONE
                    }
                } catch (_: SecurityException) {
                    finishWithError(
                        "qr_permission_denied",
                        "Camera permission for QR scanning was denied.",
                    )
                } catch (_: Exception) {
                    finishWithError(
                        "qr_camera_in_use",
                        "The camera is unavailable or already in use.",
                    )
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    @androidx.annotation.OptIn(
        markerClass = [androidx.camera.core.ExperimentalGetImage::class],
    )
    private fun analyze(imageProxy: ImageProxy) {
        if (completed.get() || !analyzing.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            analyzing.set(false)
            imageProxy.close()
            return
        }
        val image = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees,
        )
        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                val barcode = barcodes.firstOrNull { !it.rawValue.isNullOrEmpty() }
                if (barcode != null) finishWithSuccess(barcode)
            }
            .addOnCompleteListener {
                analyzing.set(false)
                imageProxy.close()
            }
    }

    private fun toggleTorch() {
        val activeCamera = camera ?: return
        if (activeCamera.cameraInfo.hasFlashUnit() != true) return
        val next = !torchEnabled
        val future = activeCamera.cameraControl.enableTorch(next)
        future.addListener(
            {
                try {
                    future.get()
                    torchEnabled = next
                    torchButton?.text = if (next) "Light off" else "Light"
                } catch (_: Exception) {
                    torchEnabled = false
                    torchButton?.text = "Light"
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun finishWithSuccess(barcode: Barcode) {
        val rawValue = barcode.rawValue ?: return
        if (!completed.compareAndSet(false, true)) return
        setResult(
            Activity.RESULT_OK,
            Intent()
                .putExtra(EXTRA_RAW_VALUE, rawValue)
                .putExtra(EXTRA_VALUE_TYPE, valueType(barcode.valueType))
                .putExtra(EXTRA_SCANNED_AT_UTC, utcTimestamp()),
        )
        finish()
    }

    private fun finishWithError(code: String, message: String) {
        if (!completed.compareAndSet(false, true)) return
        setResult(
            Activity.RESULT_CANCELED,
            Intent()
                .putExtra(EXTRA_ERROR_CODE, code)
                .putExtra(EXTRA_ERROR_MESSAGE, message),
        )
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        finishWithError("qr_scan_cancelled", "QR scanning was cancelled.")
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(timeoutRunnable)
        try {
            camera?.cameraControl?.enableTorch(false)
            cameraProvider?.unbindAll()
        } catch (_: Exception) {
            // Lifecycle cleanup is best effort.
        }
        if (::scanner.isInitialized) scanner.close()
        analysisExecutor.shutdownNow()
        if (active.get() === this) active.clear()
        super.onDestroy()
    }

    private fun valueType(type: Int): String = when (type) {
        Barcode.TYPE_URL -> "url"
        Barcode.TYPE_WIFI -> "wifi"
        Barcode.TYPE_CONTACT_INFO -> "contact"
        Barcode.TYPE_EMAIL -> "email"
        Barcode.TYPE_PHONE -> "phone"
        Barcode.TYPE_SMS -> "sms"
        Barcode.TYPE_GEO -> "geo"
        Barcode.TYPE_CALENDAR_EVENT -> "calendar"
        Barcode.TYPE_DRIVER_LICENSE -> "driverLicense"
        Barcode.TYPE_TEXT -> "text"
        else -> "unknown"
    }

    private fun utcTimestamp(): String = SimpleDateFormat(
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        Locale.US,
    ).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date())
}
