package com.mehedi.miniappstore.mini_app_store_host

import android.app.Activity
import android.app.Application
import android.app.Dialog
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.CacheKeyFactory
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.lang.ref.WeakReference
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/** Host-owned Media3 bridge installed by mini_program_tooling. */
@UnstableApi
internal class MiniProgramMediaPlaybackPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "mini_program/media_playback"
        private const val VIEW_TYPE = "mini_program/media_playback_view"

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramMediaPlaybackPlugin())
        }
    }

    private var applicationContext: Context? = null
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null
    private val sessions = linkedMapOf<String, NativeSession>()
    private var cachePool: MediaCachePool? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        cachePool = MediaCachePool(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            MediaViewFactory(this),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        releaseAll()
        cachePool?.close()
        cachePool = null
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding.activity)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity(release = false)
    }

    override fun onDetachedFromActivity() {
        detachActivity(release = true)
    }

    private fun attachActivity(value: Activity) {
        detachActivity(release = false)
        activity = value
        val callbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit
            override fun onActivityStarted(activity: Activity) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivityStopped(stopped: Activity) {
                if (stopped === this@MiniProgramMediaPlaybackPlugin.activity) {
                    pauseAll()
                }
            }
            override fun onActivityDestroyed(destroyed: Activity) {
                if (destroyed === this@MiniProgramMediaPlaybackPlugin.activity &&
                    !destroyed.isChangingConfigurations
                ) {
                    releaseAll()
                }
            }
        }
        lifecycleCallbacks = callbacks
        value.application.registerActivityLifecycleCallbacks(callbacks)
    }

    private fun detachActivity(release: Boolean) {
        val current = activity
        val callbacks = lifecycleCallbacks
        if (current != null && callbacks != null) {
            current.application.unregisterActivityLifecycleCallbacks(callbacks)
        }
        lifecycleCallbacks = null
        activity = null
        sessions.values.forEach { it.exitFullscreen() }
        if (release) releaseAll() else pauseAll()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> create(call, result)
            "play" -> command(call, result) { it.play() }
            "pause" -> command(call, result) { it.pause() }
            "seek" -> command(call, result) {
                it.seek(requiredLong(call, "value"))
            }
            "stop" -> command(call, result) { it.stop() }
            "setMuted" -> command(call, result) {
                it.setMuted(requiredBoolean(call, "value"))
            }
            "setVolume" -> command(call, result) {
                it.setVolume(requiredDouble(call, "value"))
            }
            "setSpeed" -> command(call, result) {
                it.setSpeed(requiredDouble(call, "value"))
            }
            "enterFullscreen" -> command(call, result) {
                it.enterFullscreen(activity)
            }
            "exitFullscreen" -> command(call, result) { it.exitFullscreen() }
            "release" -> release(call, result)
            else -> result.notImplemented()
        }
    }

    private fun create(call: MethodCall, result: MethodChannel.Result) {
        val context = applicationContext
        val pool = cachePool
        if (context == null || pool == null) {
            result.error(
                "media_provider_unavailable",
                "Android media playback is detached from the Flutter engine.",
                null,
            )
            return
        }
        try {
            val args = requiredArguments(call)
            val sessionId = requiredString(args, "sessionId")
            if (sessions.containsKey(sessionId)) {
                result.error(
                    "media_request_in_progress",
                    "The Android media session already exists.",
                    null,
                )
                return
            }
            val session = NativeSession(
                context = context,
                channel = channel,
                cachePool = pool,
                arguments = args,
            )
            sessions[sessionId] = session
            session.prepare(result) {
                sessions.remove(sessionId)
            }
        } catch (error: NativeMediaException) {
            result.error(error.code, error.message, null)
        } catch (_: Exception) {
            result.error(
                "media_load_failed",
                "Android could not create the media session.",
                null,
            )
        }
    }

    private fun command(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (NativeSession) -> Unit,
    ) {
        try {
            val session = requiredSession(call)
            operation(session)
            result.success(null)
        } catch (error: NativeMediaException) {
            result.error(error.code, error.message, null)
        } catch (_: Exception) {
            result.error(
                "media_playback_failed",
                "Android media playback failed.",
                null,
            )
        }
    }

    private fun release(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = requiredArguments(call)
            val sessionId = requiredString(args, "sessionId")
            sessions.remove(sessionId)?.release()
            result.success(null)
        } catch (error: NativeMediaException) {
            result.error(error.code, error.message, null)
        }
    }

    private fun requiredSession(call: MethodCall): NativeSession {
        val sessionId = requiredString(requiredArguments(call), "sessionId")
        return sessions[sessionId] ?: throw NativeMediaException(
            "media_player_not_found",
            "The Android media session is not loaded.",
        )
    }

    private fun requiredArguments(call: MethodCall): Map<*, *> =
        call.arguments as? Map<*, *> ?: throw NativeMediaException(
            "media_playback_failed",
            "The Android media request is invalid.",
        )

    private fun requiredString(args: Map<*, *>, key: String): String =
        (args[key] as? String)?.takeIf { it.isNotBlank() }
            ?: throw NativeMediaException(
                "media_playback_failed",
                "The Android media request is missing $key.",
            )

    private fun requiredLong(call: MethodCall, key: String): Long =
        ((call.arguments as? Map<*, *>)?.get(key) as? Number)?.toLong()
            ?: throw NativeMediaException(
                "media_playback_failed",
                "The Android media request is missing $key.",
            )

    private fun requiredDouble(call: MethodCall, key: String): Double =
        ((call.arguments as? Map<*, *>)?.get(key) as? Number)?.toDouble()
            ?: throw NativeMediaException(
                "media_playback_failed",
                "The Android media request is missing $key.",
            )

    private fun requiredBoolean(call: MethodCall, key: String): Boolean =
        (call.arguments as? Map<*, *>)?.get(key) as? Boolean
            ?: throw NativeMediaException(
                "media_playback_failed",
                "The Android media request is missing $key.",
            )

    internal fun attachView(sessionId: String, view: PlayerView) {
        sessions[sessionId]?.attachInlineView(view)
    }

    internal fun detachView(sessionId: String, view: PlayerView) {
        sessions[sessionId]?.detachInlineView(view)
    }

    private fun pauseAll() {
        sessions.values.forEach { it.pause() }
    }

    private fun releaseAll() {
        val owned = sessions.values.toList()
        sessions.clear()
        owned.forEach { it.release() }
    }
}

private class NativeMediaException(val code: String, override val message: String) :
    Exception(message)

@UnstableApi
private class NativeSession(
    context: Context,
    private val channel: MethodChannel?,
    cachePool: MediaCachePool,
    arguments: Map<*, *>,
) : Player.Listener {
    private val handler = Handler(Looper.getMainLooper())
    private val sessionId = requiredString(arguments, "sessionId")
    private val miniProgramId = requiredString(arguments, "miniProgramId")
    private val playerId = requiredString(arguments, "playerId")
    private val kind = requiredString(arguments, "kind")
    private val uri = requiredString(arguments, "uri")
    private val sourceKey = requiredString(arguments, "sourceKey")
    private val cacheMode = requiredString(arguments, "cacheMode")
    private val autoplay = arguments["autoplay"] as? Boolean ?: false
    private val loop = arguments["loop"] as? Boolean ?: false
    private var requestedVolume = (arguments["volume"] as? Number)?.toFloat() ?: 1f
    private var muted = arguments["muted"] as? Boolean ?: false
    private val speed = (arguments["speed"] as? Number)?.toFloat() ?: 1f
    private val timeoutMs = (arguments["timeoutMs"] as? Number)?.toLong() ?: 10_000L
    private val cacheLease: MediaCacheLease?
    private val player: ExoPlayer
    private var pendingResult: MethodChannel.Result? = null
    private var released = false
    private var inlineView = WeakReference<PlayerView>(null)
    private var fullscreenDialog: Dialog? = null
    private var fullscreenView: PlayerView? = null
    private val resultCompleted = AtomicBoolean(false)

    private val progressTick = object : Runnable {
        override fun run() {
            if (released) return
            if (player.isPlaying || player.playbackState == Player.STATE_BUFFERING) {
                emitSnapshot()
            }
            handler.postDelayed(this, 500L)
        }
    }

    init {
        val headers = (arguments["headers"] as? Map<*, *>)
            ?.entries
            ?.associate { it.key.toString() to it.value.toString() }
            ?: emptyMap()
        val httpFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(false)
            .setConnectTimeoutMs(timeoutMs.coerceIn(1_000L, 60_000L).toInt())
            .setReadTimeoutMs(timeoutMs.coerceIn(1_000L, 60_000L).toInt())
            .setDefaultRequestProperties(headers)
        val dataSourceFactory: DataSource.Factory
        if (cacheMode == "temporary") {
            val maxBytes = (arguments["maxCacheBytes"] as? Number)?.toLong()
                ?: throw NativeMediaException(
                    "media_cache_failed",
                    "The accepted temporary media cache has no byte limit.",
                )
            val ttlMs = (arguments["cacheTtlMs"] as? Number)?.toLong()
                ?: throw NativeMediaException(
                    "media_cache_failed",
                    "The accepted temporary media cache has no TTL.",
                )
            cacheLease = cachePool.acquire(
                miniProgramId = miniProgramId,
                kind = kind,
                maxBytes = maxBytes,
                ttlMs = ttlMs,
            )
            val namespace = sha256("$miniProgramId|$kind|$sourceKey")
            dataSourceFactory = CacheDataSource.Factory()
                .setCache(cacheLease.cache)
                .setUpstreamDataSourceFactory(httpFactory)
                .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
                .setCacheKeyFactory(CacheKeyFactory { dataSpec ->
                    sha256("$namespace|${dataSpec.uri}")
                })
        } else {
            cacheLease = null
            dataSourceFactory = httpFactory
        }
        val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory)
        player = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(if (kind == "video") C.USAGE_MEDIA else C.USAGE_MEDIA)
            .setContentType(
                if (kind == "video") C.AUDIO_CONTENT_TYPE_MOVIE
                else C.AUDIO_CONTENT_TYPE_MUSIC,
            )
            .build()
        player.setAudioAttributes(audioAttributes, true)
        player.setHandleAudioBecomingNoisy(true)
        player.repeatMode = if (loop) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
        player.volume = if (muted) 0f else requestedVolume.coerceIn(0f, 1f)
        player.setPlaybackSpeed(speed.coerceIn(0.25f, 3f))
        player.addListener(this)
        player.setMediaItem(MediaItem.fromUri(uri))
    }

    fun prepare(result: MethodChannel.Result, onFailed: () -> Unit) {
        pendingResult = result
        handler.postDelayed({
            if (resultCompleted.compareAndSet(false, true)) {
                pendingResult = null
                onFailed()
                result.error(
                    "media_timeout",
                    "Android media loading timed out.",
                    null,
                )
                release()
            }
        }, timeoutMs.coerceIn(1_000L, 60_000L))
        handler.post(progressTick)
        player.prepare()
        player.playWhenReady = autoplay
    }

    fun play() {
        ensureActive()
        player.play()
    }

    fun pause() {
        if (!released) player.pause()
    }

    fun seek(positionMs: Long) {
        ensureActive()
        val duration = player.duration
        val target = if (duration == C.TIME_UNSET || duration <= 0L) {
            positionMs.coerceAtLeast(0L)
        } else {
            positionMs.coerceIn(0L, duration)
        }
        player.seekTo(target)
    }

    fun stop() {
        ensureActive()
        player.pause()
        player.seekTo(0L)
    }

    fun setMuted(value: Boolean) {
        ensureActive()
        muted = value
        player.volume = if (muted) 0f else requestedVolume.coerceIn(0f, 1f)
        emitSnapshot()
    }

    fun setVolume(value: Double) {
        ensureActive()
        requestedVolume = value.toFloat().coerceIn(0f, 1f)
        player.volume = if (muted) 0f else requestedVolume
        emitSnapshot()
    }

    fun setSpeed(value: Double) {
        ensureActive()
        player.setPlaybackSpeed(value.toFloat().coerceIn(0.25f, 3f))
        emitSnapshot()
    }

    fun attachInlineView(view: PlayerView) {
        ensureActive()
        inlineView.get()?.player = null
        inlineView = WeakReference(view)
        if (fullscreenDialog == null) view.player = player
    }

    fun detachInlineView(view: PlayerView) {
        if (inlineView.get() === view) {
            view.player = null
            inlineView.clear()
        }
    }

    fun enterFullscreen(activity: Activity?) {
        ensureActive()
        if (kind != "video" || activity == null || activity.isFinishing) {
            throw NativeMediaException(
                "media_fullscreen_unavailable",
                "Fullscreen video requires a foreground Android activity.",
            )
        }
        if (fullscreenDialog != null) return
        inlineView.get()?.player = null
        val view = PlayerView(activity).apply {
            useController = true
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
            player = this@NativeSession.player
        }
        val dialog = Dialog(
            activity,
            android.R.style.Theme_Black_NoTitleBar_Fullscreen,
        )
        dialog.setContentView(view)
        dialog.setOnDismissListener {
            view.player = null
            fullscreenView = null
            fullscreenDialog = null
            inlineView.get()?.player = player
        }
        dialog.show()
        dialog.window?.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        dialog.window?.decorView?.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        fullscreenView = view
        fullscreenDialog = dialog
    }

    fun exitFullscreen() {
        fullscreenDialog?.dismiss()
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        if (playbackState == Player.STATE_READY &&
            resultCompleted.compareAndSet(false, true)
        ) {
            pendingResult?.success(snapshot())
            pendingResult = null
        }
        emitSnapshot()
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        emitSnapshot()
    }

    override fun onPlayerError(error: PlaybackException) {
        val code = playbackErrorCode(error)
        val message = when (code) {
            "media_network_error" -> "Android could not reach the media source."
            "media_unsupported_format" -> "Android does not support this media format."
            else -> "Android media playback failed."
        }
        if (resultCompleted.compareAndSet(false, true)) {
            pendingResult?.error(code, message, null)
            pendingResult = null
        }
        emitSnapshot()
    }

    private fun snapshot(): Map<String, Any?> {
        val duration = player.duration
        val status = when {
            player.playerError != null -> "error"
            player.playbackState == Player.STATE_BUFFERING -> "buffering"
            player.playbackState == Player.STATE_ENDED -> "completed"
            player.isPlaying -> "playing"
            player.playbackState == Player.STATE_IDLE -> "idle"
            player.currentPosition > 0L -> "paused"
            else -> "ready"
        }
        return linkedMapOf(
            "playerId" to playerId,
            "kind" to kind,
            "status" to status,
            "positionMs" to player.currentPosition.coerceAtLeast(0L),
            "durationMs" to if (duration == C.TIME_UNSET || duration < 0L) null
                else duration,
            "bufferedMs" to player.bufferedPosition.coerceAtLeast(0L),
            "volume" to requestedVolume.toDouble(),
            "speed" to player.playbackParameters.speed.toDouble(),
            "muted" to muted,
        )
    }

    private fun emitSnapshot() {
        if (released) return
        channel?.invokeMethod(
            "playbackEvent",
            mapOf("sessionId" to sessionId, "snapshot" to snapshot()),
        )
    }

    private fun playbackErrorCode(error: PlaybackException): String {
        val name = error.errorCodeName
        return when {
            name.startsWith("ERROR_CODE_IO_") -> "media_network_error"
            name.contains("DECOD") || name.contains("FORMAT") ||
                name.contains("PARSING") -> "media_unsupported_format"
            else -> "media_playback_failed"
        }
    }

    private fun ensureActive() {
        if (released) {
            throw NativeMediaException(
                "media_player_not_found",
                "The Android media session has been released.",
            )
        }
    }

    fun release() {
        if (released) return
        released = true
        handler.removeCallbacksAndMessages(null)
        if (resultCompleted.compareAndSet(false, true)) {
            pendingResult?.error(
                "media_interrupted",
                "Android media loading was interrupted.",
                null,
            )
        }
        pendingResult = null
        exitFullscreen()
        inlineView.get()?.player = null
        inlineView.clear()
        player.removeListener(this)
        player.release()
        cacheLease?.release()
    }

    private fun requiredString(args: Map<*, *>, key: String): String =
        (args[key] as? String)?.takeIf { it.isNotBlank() }
            ?: throw NativeMediaException(
                "media_playback_failed",
                "The Android media request is missing $key.",
            )
}

@UnstableApi
private class MediaCachePool(private val context: Context) {
    private data class Entry(
        val cache: SimpleCache,
        val maxBytes: Long,
        var references: Int,
    )

    private val entries = linkedMapOf<String, Entry>()

    @Synchronized
    fun acquire(
        miniProgramId: String,
        kind: String,
        maxBytes: Long,
        ttlMs: Long,
    ): MediaCacheLease {
        if (maxBytes <= 0L || ttlMs <= 0L) {
            throw NativeMediaException(
                "media_cache_failed",
                "The accepted temporary media cache policy is invalid.",
            )
        }
        val key = sha256("$miniProgramId|$kind")
        var entry = entries[key]
        if (entry != null && entry.maxBytes != maxBytes) {
            if (entry.references > 0) {
                throw NativeMediaException(
                    "media_cache_failed",
                    "The accepted media cache policy changed while in use.",
                )
            }
            entry.cache.release()
            entries.remove(key)
            entry = null
        }
        if (entry == null) {
            val directory = File(context.cacheDir, "mini_program_media3/$key")
            directory.mkdirs()
            entry = Entry(
                cache = SimpleCache(
                    directory,
                    LeastRecentlyUsedCacheEvictor(maxBytes),
                    StandaloneDatabaseProvider(context),
                ),
                maxBytes = maxBytes,
                references = 0,
            )
            entries[key] = entry
        }
        cleanupExpired(entry.cache, ttlMs)
        entry.references++
        return MediaCacheLease(entry.cache) {
            synchronized(this) {
                entry.references = (entry.references - 1).coerceAtLeast(0)
            }
        }
    }

    private fun cleanupExpired(cache: SimpleCache, ttlMs: Long) {
        val cutoff = System.currentTimeMillis() - ttlMs
        cache.keys.toList().forEach { key ->
            val spans = cache.getCachedSpans(key)
            if (spans.isNotEmpty() && spans.all {
                    it.lastTouchTimestamp > 0L && it.lastTouchTimestamp < cutoff
                }
            ) {
                cache.removeResource(key)
            }
        }
    }

    @Synchronized
    fun close() {
        entries.values.forEach { it.cache.release() }
        entries.clear()
    }
}

@UnstableApi
private class MediaCacheLease(
    val cache: SimpleCache,
    private val onRelease: () -> Unit,
) {
    private var released = false

    fun release() {
        if (released) return
        released = true
        onRelease()
    }
}

@UnstableApi
private class MediaViewFactory(
    private val plugin: MiniProgramMediaPlaybackPlugin,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<Any, Any>()
        val sessionId = params["sessionId"] as? String ?: ""
        val fit = params["fit"] as? String ?: "contain"
        return MediaPlatformView(context, plugin, sessionId, fit)
    }
}

@UnstableApi
private class MediaPlatformView(
    context: Context,
    private val plugin: MiniProgramMediaPlaybackPlugin,
    private val sessionId: String,
    fit: String,
) : PlatformView {
    private val playerView = PlayerView(context).apply {
        useController = false
        resizeMode = when (fit) {
            "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
            else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
    }

    init {
        plugin.attachView(sessionId, playerView)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        plugin.detachView(sessionId, playerView)
        playerView.player = null
    }
}

private fun sha256(value: String): String = MessageDigest
    .getInstance("SHA-256")
    .digest(value.toByteArray(Charsets.UTF_8))
    .joinToString("") { "%02x".format(it) }
