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
    }
    private var player: ExoPlayer
    private val methodChannel: MethodChannel
    private var usePanExtractor: Boolean = true
    private var currentUrl: String? = null
    
    init {
        android.util.Log.d("NativePlayerView", "Initializing NativePlayerView (id=$id)")
        // Setup MethodChannel for remote control event forwarding
        methodChannel = MethodChannel(messenger, "native_video_player_${id}")
        
        // Enhanced Player initialization with LoadControl and FFmpeg Support
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                15000, // min buffer (15 seconds)
                50000, // max buffer (50 seconds)
                1500,  // buffer for playback (fast start)
                2500   // buffer for resume
            )
            .build()
            
        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)

        player = ExoPlayer.Builder(context, renderersFactory)
            .setLoadControl(loadControl)
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
                val stateString = when (state) {
                    androidx.media3.common.Player.STATE_IDLE -> "IDLE"
                    androidx.media3.common.Player.STATE_BUFFERING -> "BUFFERING"
                    androidx.media3.common.Player.STATE_READY -> "READY"
                    androidx.media3.common.Player.STATE_ENDED -> "ENDED"
                    else -> "UNKNOWN"
                }
                android.util.Log.d("NativePlayerView", "Playback state changed: $stateString")
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                android.util.Log.e("NativePlayerView", "Player error: ${error.message}", error)
                Handler(Looper.getMainLooper()).post {
                    methodChannel.invokeMethod(
                        "onPlayerError",
                        mapOf("message" to (error.message ?: "Stream unavailable"))
                    )
                }
            }
        })

        val url = creationParams?.get("streamUrl") as? String
        if (url != null) {
            android.util.Log.d("NativePlayerView", "Initial prepare for: $url")
            preparePlayer(url)
        }
    }

    private fun preparePlayer(url: String) {
        if (url.isEmpty()) return
        
        if (url == currentUrl && player.playbackState != androidx.media3.common.Player.STATE_IDLE) {
            android.util.Log.i("NativePlayerView", "Ignoring duplicate prepare for: $url")
            return
        }
        currentUrl = url
        android.util.Log.i("NativePlayerView", "preparePlayer URL: $url")

        val drmInst = com.panaccess.android.drm.PanaccessDrm.getInst()

        if (!drmInst.isInitialized || !drmInst.isPersonalized) {
            android.util.Log.e("NativePlayerView", "DRM NOT READY — scheduling retry...")
            Handler(Looper.getMainLooper()).postDelayed({
                if (currentUrl == url) {
                    preparePlayer(url)
                }
            }, 1000)
            return
        }

        try {
            val context = playerView.context
            
            // KEY FIX: Revert to DefaultDataSource.Factory for standard HTTP proxies!
            // PanUdpDataSourceFactory crashes with `port out of range` on `http://` streams.
            val dataSourceFactory = DefaultDataSource.Factory(context)
            val mediaItem = MediaItem.fromUri(url)
            
            val mediaSource = if (usePanExtractor || url.contains(".m3u8", ignoreCase = true)) {
                val hlsFactory = HlsMediaSource.Factory(dataSourceFactory)
                if (usePanExtractor) {
                    hlsFactory.setExtractorFactory(PanHlsExtractorFactory())
                }
                hlsFactory.createMediaSource(mediaItem)
            } else {
                androidx.media3.exoplayer.source.DefaultMediaSourceFactory(dataSourceFactory)
                    .createMediaSource(mediaItem)
            }

            android.util.Log.d("NativePlayerView", "Setting media source...")
            player.stop()
            player.clearMediaItems()
            player.setMediaSource(mediaSource)
            player.prepare()
            player.playWhenReady = true

            android.util.Log.i("NativePlayerView", "Prepare successful for: $url")

        } catch (e: Exception) {
            android.util.Log.e("NativePlayerView", "CRITICAL FAILURE in preparePlayer: ${e.message}", e)
        }
    }

    override fun getView(): View {
        return playerView
    }

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        player.release()
    }
}
