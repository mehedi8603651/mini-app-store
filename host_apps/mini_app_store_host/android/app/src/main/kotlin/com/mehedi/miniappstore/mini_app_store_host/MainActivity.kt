package com.mehedi.miniappstore.mini_app_store_host

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "mini_program/location"
        private const val LOCATION_PERMISSION_REQUEST = 4101
        private const val PREFS_NAME = "mini_program_location"
        private const val PREF_PERMISSION_REQUESTED = "coarse_permission_requested"
        private const val DEFAULT_TIMEOUT_MS = 10_000L
        private const val MAX_CACHED_LOCATION_AGE_MS = 15 * 60_000L
        private const val CACHED_FALLBACK_DELAY_MS = 2_500L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingResult: MethodChannel.Result? = null
    private var pendingTimeoutMs = DEFAULT_TIMEOUT_MS
    private var permissionHadBeenRequested = false
    private var awaitingPermission = false
    private var locationListener: LocationListener? = null
    private var cancellationSignal: CancellationSignal? = null
    private var timeoutRunnable: Runnable? = null
    private var cachedFallbackRunnable: Runnable? = null
    private var cachedFallbackLocation: Location? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler(::handleLocationCall)
    }

    private fun handleLocationCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "getCurrentLocation") {
            result.notImplemented()
            return
        }
        if (pendingResult != null) {
            result.error(
                "location_request_in_progress",
                "A current-location request is already in progress.",
                null,
            )
            return
        }
        val arguments = call.arguments as? Map<*, *>
        if (arguments?.get("accuracy") != "approximate") {
            result.error(
                "location_invalid_result",
                "Only approximate location is supported.",
                null,
            )
            return
        }
        val timeoutMs = (arguments?.get("timeoutMs") as? Number)?.toLong()
        if (timeoutMs == null || timeoutMs !in 1_000L..60_000L) {
            result.error(
                "location_invalid_result",
                "Location timeout must be from 1 to 60 seconds.",
                null,
            )
            return
        }

        pendingResult = result
        pendingTimeoutMs = timeoutMs
        scheduleTimeout()

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (!locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            failPending(
                "location_service_disabled",
                "Android network location services are disabled.",
            )
            return
        }

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            startLocationRequest(locationManager)
            return
        }

        val preferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        permissionHadBeenRequested = preferences.getBoolean(
            PREF_PERMISSION_REQUESTED,
            false,
        )
        if (permissionHadBeenRequested &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                this,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
        ) {
            failPending(
                "location_permission_denied_permanently",
                "Approximate location permission is permanently denied.",
            )
            return
        }

        awaitingPermission = true
        preferences.edit().putBoolean(PREF_PERMISSION_REQUESTED, true).apply()
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
            LOCATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_PERMISSION_REQUEST || pendingResult == null) {
            return
        }
        awaitingPermission = false
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            startLocationRequest(manager)
            return
        }
        val permanentlyDenied = permissionHadBeenRequested &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                this,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
        failPending(
            if (permanentlyDenied) {
                "location_permission_denied_permanently"
            } else {
                "location_permission_denied"
            },
            if (permanentlyDenied) {
                "Approximate location permission is permanently denied."
            } else {
                "Approximate location permission was denied."
            },
        )
    }

    private fun startLocationRequest(locationManager: LocationManager) {
        if (pendingResult == null) return
        if (!locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            failPending(
                "location_service_disabled",
                "Android network location services are disabled.",
            )
            return
        }
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            failPending(
                "location_permission_denied",
                "Approximate location permission was denied.",
            )
            return
        }

        try {
            cachedFallbackLocation = recentNetworkLocation(locationManager)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val signal = CancellationSignal()
                cancellationSignal = signal
                locationManager.getCurrentLocation(
                    LocationManager.NETWORK_PROVIDER,
                    signal,
                    mainExecutor,
                ) { location ->
                    if (location == null) {
                        if (!completeWithCachedFallback()) {
                            failPending(
                                "location_unavailable",
                                "Android could not determine the current location.",
                            )
                        }
                    } else {
                        completePending(location)
                    }
                }
                scheduleCachedFallback()
            } else {
                @Suppress("DEPRECATION")
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        completePending(location)
                    }

                    override fun onProviderDisabled(provider: String) {
                        failPending(
                            "location_service_disabled",
                            "Android network location services are disabled.",
                        )
                    }

                    @Deprecated("Deprecated by Android")
                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

                    override fun onProviderEnabled(provider: String) = Unit
                }
                locationListener = listener
                @Suppress("DEPRECATION")
                locationManager.requestSingleUpdate(
                    LocationManager.NETWORK_PROVIDER,
                    listener,
                    Looper.getMainLooper(),
                )
                scheduleCachedFallback()
            }
        } catch (_: SecurityException) {
            failPending(
                "location_permission_denied",
                "Approximate location permission was denied.",
            )
        } catch (_: Exception) {
            if (!completeWithCachedFallback()) {
                failPending(
                    "location_unavailable",
                    "Android current location is unavailable.",
                )
            }
        }
    }

    private fun recentNetworkLocation(locationManager: LocationManager): Location? {
        val location = try {
            @Suppress("MissingPermission")
            locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
        } catch (_: Exception) {
            null
        } ?: return null
        val ageMs = System.currentTimeMillis() - location.time
        if (ageMs !in 0..MAX_CACHED_LOCATION_AGE_MS) return null
        if (!location.latitude.isFinite() || location.latitude !in -90.0..90.0) return null
        if (!location.longitude.isFinite() || location.longitude !in -180.0..180.0) return null
        if (location.hasAccuracy() &&
            (!location.accuracy.isFinite() || location.accuracy < 0f)
        ) {
            return null
        }
        return location
    }

    private fun scheduleCachedFallback() {
        if (cachedFallbackLocation == null) return
        val delayMs = minOf(
            CACHED_FALLBACK_DELAY_MS,
            (pendingTimeoutMs - 500L).coerceAtLeast(500L),
        )
        val runnable = Runnable { completeWithCachedFallback() }
        cachedFallbackRunnable = runnable
        mainHandler.postDelayed(runnable, delayMs)
    }

    private fun completeWithCachedFallback(): Boolean {
        val location = cachedFallbackLocation ?: return false
        if (pendingResult == null) return false
        completePending(location)
        return true
    }

    private fun scheduleTimeout() {
        val runnable = Runnable {
            if (!completeWithCachedFallback()) {
                failPending(
                    "location_timeout",
                    "The current-location request timed out. Check Wi-Fi, mobile data, and Android location accuracy settings.",
                )
            }
        }
        timeoutRunnable = runnable
        mainHandler.postDelayed(runnable, pendingTimeoutMs)
    }

    private fun completePending(location: Location) {
        val result = pendingResult ?: return
        clearPending()
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        result.success(
            mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracyMeters" to if (location.hasAccuracy()) {
                    location.accuracy.toDouble()
                } else {
                    0.0
                },
                "capturedAtUtc" to formatter.format(Date(location.time)),
                "source" to "device",
            ),
        )
    }

    private fun failPending(code: String, message: String) {
        val result = pendingResult ?: return
        clearPending()
        result.error(code, message, null)
    }

    private fun clearPending() {
        timeoutRunnable?.let(mainHandler::removeCallbacks)
        timeoutRunnable = null
        cachedFallbackRunnable?.let(mainHandler::removeCallbacks)
        cachedFallbackRunnable = null
        cachedFallbackLocation = null
        cancellationSignal?.cancel()
        cancellationSignal = null
        val listener = locationListener
        if (listener != null) {
            val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            manager.removeUpdates(listener)
        }
        locationListener = null
        pendingResult = null
        awaitingPermission = false
    }

    override fun onStop() {
        if (pendingResult != null && !awaitingPermission) {
            failPending(
                "location_unavailable",
                "The location request stopped when the host left the foreground.",
            )
        }
        super.onStop()
    }

    override fun onDestroy() {
        if (pendingResult != null) {
            failPending(
                "location_unavailable",
                "The location request stopped because the host was destroyed.",
            )
        }
        super.onDestroy()
    }
}
