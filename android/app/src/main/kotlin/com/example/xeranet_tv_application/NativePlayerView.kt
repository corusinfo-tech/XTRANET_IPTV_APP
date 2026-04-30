package com.example.xeranet_tv_application

import android.content.Context
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DataSource
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import io.flutter.plugin.common.BinaryMessenger
import android.os.Handler
import android.os.Looper

import com.panaccess.android.exoplayer.PanHlsExtractorFactory
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.LoadControl

class NativePlayerView(context: Context, id: Int, creationParams: Map<String, Any>?, messenger: BinaryMessenger) : PlatformView {
    private val playerView: PlayerView = PlayerView(context).apply {
        layoutParams = android.view.ViewGroup.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.ViewGroup.LayoutParams.MATCH_PARENT
        )
        // FORCE SurfaceView for Android TV hardware decoder compatibility
        setKeepContentOnPlayerReset(true)
        keepScreenOn = true // Prevent TV from sleeping during long playback
    }
    private var player: ExoPlayer
    private val methodChannel: MethodChannel = MethodChannel(messenger, "native_video_player_${id}")
    private var usePanExtractor: Boolean = true
    private var currentUrl: String? = null
    private var retryCount = 0
    private val maxRetries = 3
    private val bufferingHandler = Handler(Looper.getMainLooper())
    private val bufferingTimeout = Runnable {
        android.util.Log.w("NativePlayerView", "Buffering timeout reached (15s) — triggering auto-retry")
        if (retryCount < maxRetries) {
            retryCount++
            val urlToRetry = currentUrl
            currentUrl = null // Bypass the duplicate prepare check
            urlToRetry?.let { preparePlayer(it) }
        } else {
            methodChannel.invokeMethod("onPlayerError", mapOf("message" to "Stream timed out while buffering"))
        }
    }
    
    init {
        android.util.Log.d("NativePlayerView", "Initializing NativePlayerView (id=$id)")
        
        // Enhanced Player initialization with Optimized LoadControl (Addressing Buffering Issues)
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                2500,  // min buffer (2.5 seconds) - Drastically reduced for faster start
                30000, // max buffer (30 seconds) - Reduced to prevent memory bloat and slowness
                500,   // buffer for playback (0.5 seconds) - Near-instant start
                1000   // buffer for resume
            )
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()
            
        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
            .setEnableDecoderFallback(true) // Fallback to software decoders
            .setMediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->
                // This helps bypass strict profile checks that cause black screens on older TVs (Sony/Acer)
                androidx.media3.exoplayer.mediacodec.MediaCodecSelector.DEFAULT
                    .getDecoderInfos(mimeType, requiresSecureDecoder, requiresTunnelingDecoder)
            }

        player = ExoPlayer.Builder(context, renderersFactory)
            .setLoadControl(loadControl)
            .build()

        // SET 1080p AS DEFAULT CLARITY AND ALLOW ADAPTIVENESS FOR COMPATIBILITY
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .setMaxVideoSize(1920, 1080)
            .build()

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "dispatchKeyEvent" -> {
                    val keyCode = call.argument<Int>("keyCode")
                    if (keyCode != null) {
                        val event = android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, keyCode)
                        playerView.dispatchKeyEvent(event)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Missing keyCode", null)
                    }
                }
                "changeStream" -> {
                    val url = call.argument<String>("streamUrl")
                    if (url != null) {
                        retryCount = 0 // Reset retry count on manual change
                        preparePlayer(url)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Missing streamUrl", null)
                    }
                }
                "togglePlainExo" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    usePanExtractor = !enabled
                    currentUrl?.let { preparePlayer(it) }
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // TV specific UI/Focus configurations
        playerView.useController = false
        playerView.requestFocus()
        playerView.isFocusable = true
        playerView.isFocusableInTouchMode = true
        
        playerView.player = player
        
        // Ensure audio focus handles auto-play correctly
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
            .build()
        player.setAudioAttributes(audioAttributes, true)

        // Add Listener for debugging playback issues
        player.addListener(object : androidx.media3.common.Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                // Cancel any pending buffering timeout
                bufferingHandler.removeCallbacks(bufferingTimeout)
                
                val stateString = when (state) {
                    androidx.media3.common.Player.STATE_IDLE -> "IDLE"
                    androidx.media3.common.Player.STATE_BUFFERING -> {
                        // Start a 15-second watchdog for buffering
                        bufferingHandler.postDelayed(bufferingTimeout, 15000)
                        "BUFFERING"
                    }
                    androidx.media3.common.Player.STATE_READY -> {
                        retryCount = 0 // Reset retry count on success
                        "READY"
                    }
                    androidx.media3.common.Player.STATE_ENDED -> "ENDED"
                    else -> "UNKNOWN"
                }
                android.util.Log.d("NativePlayerView", "Playback state changed: $stateString")
                
                // Forward state to Flutter
                Handler(Looper.getMainLooper()).post {
                    methodChannel.invokeMethod("onPlayerStateChanged", mapOf("state" to stateString))
                }
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                android.util.Log.e("NativePlayerView", "Player error (retry $retryCount/$maxRetries): ${error.message}", error)
                
                if (retryCount < maxRetries) {
                    retryCount++
                    android.util.Log.i("NativePlayerView", "Auto-retrying playback in 2000ms...")
                    Handler(Looper.getMainLooper()).postDelayed({
                        currentUrl?.let { preparePlayer(it) }
                    }, 2000)
                } else {
                    Handler(Looper.getMainLooper()).post {
                        methodChannel.invokeMethod(
                            "onPlayerError",
                            mapOf("message" to (error.message ?: "Stream unavailable after retries"))
                        )
                    }
                }
            }

            override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
                android.util.Log.i("NativePlayerView", "onVideoSizeChanged: width=${videoSize.width}, height=${videoSize.height}")
            }

            override fun onRenderedFirstFrame() {
                android.util.Log.i("NativePlayerView", "onRenderedFirstFrame: First frame successfully rendered to surface")
            }
        })

        val url = creationParams?.get("streamUrl") as? String
        if (url != null) {
            android.util.Log.d("NativePlayerView", "Initial prepare for: $url")
            preparePlayer(url)
        }
    }

    private fun preparePlayer(url: String) {
        if (url.isEmpty() || url == "use_cache") {
            android.util.Log.d("NativePlayerView", "preparePlayer: Skipping invalid/placeholder URL: $url")
            return
        }
        
        if (url == currentUrl && player.playbackState != androidx.media3.common.Player.STATE_IDLE) {
            android.util.Log.i("NativePlayerView", "Ignoring duplicate prepare for: $url")
            return
        }
        currentUrl = url
        android.util.Log.i("NativePlayerView", "preparePlayer URL: $url")

        val drmInst = com.panaccess.android.drm.PanaccessDrm.getInst()

        // RELAXED Session ID Check: Only block on !isInitialized.
        // Waiting for sessionId is often too strict as it might only be set internally or after playback starts.
        if (!drmInst.isInitialized) {
            android.util.Log.e("NativePlayerView", "DRM NOT INITIALIZED — scheduling retry...")
            Handler(Looper.getMainLooper()).postDelayed({
                if (currentUrl == url) {
                    preparePlayer(url)
                }
            }, 1000)
            return
        }

        // Send DRM details to Flutter for diagnostics
        val sessionId = drmInst.sessionId ?: "NULL"
        val boxMAC = drmInst.boxMAC ?: "NULL"
        Handler(Looper.getMainLooper()).post {
            methodChannel.invokeMethod("onDrmInfo", mapOf(
                "sessionId" to sessionId,
                "boxMAC" to boxMAC,
                "isPersonalized" to drmInst.isPersonalized
            ))
        }

        // WAIT FOR SESSION ID: Encryption requires a valid session.
        if (sessionId.isEmpty() || sessionId == "NULL") {
            android.util.Log.w("NativePlayerView", "Session ID missing — retrying prepare in 200ms...")
            Handler(Looper.getMainLooper()).postDelayed({
                if (currentUrl == url) {
                    preparePlayer(url)
                }
            }, 200)
            return
        }

        if (!drmInst.isPersonalized) {
            android.util.Log.w("NativePlayerView", "Device not yet personalized — attempt playback anyway...")
        }

        try {
            val context = playerView.context
            val dataSourceFactory = DefaultDataSource.Factory(context)
            val mediaItem = MediaItem.fromUri(url)
            
            // Revert to applying PanExtractor to all HLS streams by default if enabled
            // Our conservative check might have been too strict for external encrypted streams.
            val isHls = url.contains(".m3u8", ignoreCase = true) || 
                        url.contains("localhost") || 
                        url.contains("127.0.0.1") ||
                        !url.contains("http")

            val mediaSource = if (isHls) {
                val hlsFactory = HlsMediaSource.Factory(dataSourceFactory)
                    .setAllowChunklessPreparation(true) // SUPER FAST START: skips downloading chunks for format info
                if (usePanExtractor) {
                    android.util.Log.d("NativePlayerView", "Applying PanHlsExtractorFactory for stream: $url")
                    hlsFactory.setExtractorFactory(PanHlsExtractorFactory())
                }
                hlsFactory.createMediaSource(mediaItem)
            } else {
                android.util.Log.d("NativePlayerView", "Using standard MediaSource for stream: $url")
                androidx.media3.exoplayer.source.DefaultMediaSourceFactory(dataSourceFactory)
                    .createMediaSource(mediaItem)
            }

            android.util.Log.d("NativePlayerView", "Directly preparing player with MediaSource...")
            player.stop()
            player.clearMediaItems()
            player.setMediaSource(mediaSource)
            player.prepare()
            player.playWhenReady = true

        } catch (e: Exception) {
            android.util.Log.e("NativePlayerView", "CRITICAL FAILURE in preparePlayer: ${e.message}", e)
            Handler(Looper.getMainLooper()).post {
                methodChannel.invokeMethod(
                    "onPlayerError",
                    mapOf("message" to "Playback Initialization Failed: ${e.localizedMessage}")
                )
            }
        }
    }

    override fun getView(): View {
        return playerView
    }

    override fun dispose() {
        bufferingHandler.removeCallbacks(bufferingTimeout)
        methodChannel.setMethodCallHandler(null)
        player.release()
    }
}
