package matsune.video_player

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.support.v4.media.session.MediaSessionCompat
import android.view.Surface
import com.google.android.exoplayer2.*
import com.google.android.exoplayer2.audio.AudioAttributes
import com.google.android.exoplayer2.ext.mediasession.MediaSessionConnector
import com.google.android.exoplayer2.source.hls.HlsMediaSource
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.view.TextureRegistry.SurfaceTextureEntry

internal class VideoPlayer(
        context: Context,
        private val eventChannel: EventChannel,
        private val textureEntry: SurfaceTextureEntry,
        private val customDefaultLoadControl: CustomDefaultLoadControl
) {

    private val loadControl: LoadControl
    private val exoPlayer: ExoPlayer?
    private val eventSink = QueuingEventSink()
    private val trackSelector = DefaultTrackSelector(context)
    private var surface: Surface? = null
    private var isInitialized = false
    private var lastSendBufferedPosition = 0L
    private var mediaSession: MediaSessionCompat? = null

    private var handler = Handler(Looper.getMainLooper())
    private val runnable: Runnable

    var isMuted: Boolean
        get() = (exoPlayer?.volume ?: 0f) == 0f
        set(value) {
            exoPlayer?.volume = if (value) 0f else 1f
        }

    private val duration: Long
        get() = exoPlayer?.duration ?: 0L

    var playbackSpeed: Float
        get() = exoPlayer?.playbackParameters?.speed ?: 1f
        set(value) {
            exoPlayer?.setPlaybackSpeed(value)
        }

    init {
        loadControl =
                DefaultLoadControl.Builder()
                        .setBufferDurationsMs(
                                this.customDefaultLoadControl.minBufferMs,
                                this.customDefaultLoadControl.maxBufferMs,
                                this.customDefaultLoadControl.bufferForPlaybackMs,
                                this.customDefaultLoadControl.bufferForPlaybackAfterRebufferMs
                        )
                        .build()
        exoPlayer =
                ExoPlayer.Builder(context)
                        .setTrackSelector(trackSelector)
                        .setLoadControl(loadControl)
                        .build()
        setupVideoPlayer(eventChannel, textureEntry)

        runnable =
                object : Runnable {
                    override fun run() {
                        if (exoPlayer.isPlaying) {
                            sendPositionChanged()
                        }
                        handler.postDelayed(this, 500) 
                    }
                }
    }

    fun dispose() {
        disposeMediaSession()
        //        disposeRemoteNotifications()
        handler.removeCallbacks(runnable)
        if (isInitialized) {
            exoPlayer?.stop()
        }
        textureEntry.release()
        eventChannel.setStreamHandler(null)
        surface?.release()
        exoPlayer?.release()
    }

    private fun setupVideoPlayer(eventChannel: EventChannel, textureEntry: SurfaceTextureEntry) {
        eventChannel.setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(o: Any?, sink: EventSink) {
                        eventSink.setDelegate(sink)
                    }

                    override fun onCancel(o: Any?) {
                        eventSink.setDelegate(null)
                    }
                }
        )
        surface = Surface(textureEntry.surfaceTexture())
        exoPlayer?.setVideoSurface(surface)
        exoPlayer?.setAudioAttributes(
                AudioAttributes.Builder().setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
                true
        )
        exoPlayer?.addListener(
                object : Player.Listener {
                    override fun onPlaybackStateChanged(playbackState: Int) {
                        when (playbackState) {
                            Player.STATE_BUFFERING -> {
                                val bufferedPosition = exoPlayer?.bufferedPosition ?: 0L
                                if (bufferedPosition != lastSendBufferedPosition) {
                                    val range: List<Number?> = listOf(0, bufferedPosition)
                                    sendEvent(
                                            EVENT_BUFFER_CHANGED,
                                            mapOf("bufferRange" to listOf(range))
                                    )
                                    lastSendBufferedPosition = bufferedPosition
                                }
                            }
                            Player.STATE_READY -> {
                                if (!isInitialized) {
                                    setInitialized()
                                    return
                                }
                            }
                            Player.STATE_ENDED -> {
                                //                                val event: MutableMap<String,
                                // Any?> = HashMap()
                                //                                event["event"] = "completed"
                                //                                eventSink.success(event)
                            }
                            Player.STATE_IDLE -> {
                                // no-op
                            }
                        }
                    }

                    override fun onPlayerError(error: PlaybackException) {
                        sendEvent(EVENT_ERROR, mapOf("error" to error))
                    }

                    override fun onIsPlayingChanged(isPlaying: Boolean) {
                        if (isPlaying) {
                            handler.post(runnable)
                        } else {
                            handler.removeCallbacks(runnable)
                        }
                        sendEvent(EVENT_IS_PLAYING_CHANGED, mapOf("isPlaying" to isPlaying))
                    }

                    override fun onVolumeChanged(volume: Float) {
                        sendEvent(EVENT_MUTE_CHANGED, mapOf("isMuted" to (volume == 0f)))
                    }
                }
        )
    }

    private fun setInitialized() {
        if (isInitialized) return
        isInitialized = true

        val event: MutableMap<String, Any> = HashMap()
        event["duration"] = duration
        if (exoPlayer?.videoFormat != null) {
            val videoFormat = exoPlayer.videoFormat
            var width = videoFormat?.width
            var height = videoFormat?.height
            val rotationDegrees = videoFormat?.rotationDegrees
            // Switch the width/height if video was taken in portrait mode
            if (rotationDegrees == 90 || rotationDegrees == 270) {
                width = exoPlayer.videoFormat?.height
                height = exoPlayer.videoFormat?.width
            }
            width?.let { event["width"] = it }
            height?.let { event["height"] = it }
        }
        sendEvent(EVENT_INITIALIZED, event)
    }

    private fun sendEvent(event: String, params: Map<String, Any>? = null) {
        val result: MutableMap<String, Any> = params?.toMutableMap() ?: HashMap()
        result["event"] = event
        eventSink.success(result)
    }

    private fun sendPositionChanged() {
        exoPlayer?.currentPosition?.let {
            sendEvent(EVENT_POSITION_CHANGED, mapOf("position" to it))
        }
    }

    fun setDataSource(
            uri: String?,
            headers: Map<String, String>?,
    ) {
        isInitialized = false
        val dataSourceFactory =
                DefaultHttpDataSource.Factory()
                        .setAllowCrossProtocolRedirects(true)
                        .setDefaultRequestProperties(headers ?: emptyMap())
        val mediaItem = MediaItem.Builder().setUri(uri).build()
        val mediaSource = HlsMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
        exoPlayer?.setMediaSource(mediaSource)
        exoPlayer?.prepare()
    }

    fun play() {
        exoPlayer?.play()
    }

    fun pause() {
        exoPlayer?.pause()
    }

    fun seekTo(location: Int) {
        exoPlayer?.seekTo(location.toLong())
        sendPositionChanged()
    }

    fun setTrackParameters(width: Int, height: Int, bitrate: Int) {
        val parametersBuilder = trackSelector.buildUponParameters()
        if (width != 0 && height != 0) {
            parametersBuilder.setMaxVideoSize(width, height)
        }
        if (bitrate != 0) {
            parametersBuilder.setMaxVideoBitrate(bitrate)
        }
        if (width == 0 && height == 0 && bitrate == 0) {
            parametersBuilder.clearVideoSizeConstraints()
            parametersBuilder.setMaxVideoBitrate(Int.MAX_VALUE)
        }
        trackSelector.setParameters(parametersBuilder)
    }

    fun onPictureInPictureStatusChanged(isPip: Boolean) {
        sendEvent(EVENT_PIP_CHANGED, mapOf("isPip" to isPip))
    }

    fun setupMediaSession(context: Context?): MediaSessionCompat? {
        mediaSession?.release()
        context?.let {
            val mediaButtonIntent = Intent(Intent.ACTION_MEDIA_BUTTON)
            val pendingIntent =
                    PendingIntent.getBroadcast(
                            context,
                            0,
                            mediaButtonIntent,
                            PendingIntent.FLAG_IMMUTABLE
                    )
            val mediaSession = MediaSessionCompat(context, TAG, null, pendingIntent)
            //            mediaSession.setCallback(
            //                    object : MediaSessionCompat.Callback() {
            //                        override fun onSeekTo(pos: Long) {
            //                            //                    sendSeekToEvent(pos)
            //                            Log.d(TAG, ">>>mediaSession onSeekTo $pos")
            //                            super.onSeekTo(pos)
            //                        }
            //
            //                        on
            //                    }
            //            )
            mediaSession.isActive = true
            val mediaSessionConnector = MediaSessionConnector(mediaSession)
            mediaSessionConnector.setPlayer(exoPlayer)
            this.mediaSession = mediaSession
            return mediaSession
        }
        return null
    }

    fun disposeMediaSession() {
        if (mediaSession != null) {
            mediaSession?.release()
        }
        mediaSession = null
    }

    companion object {
        private const val TAG = "VideoPlayer"

        private const val EVENT_INITIALIZED = "initialized"
        private const val EVENT_IS_PLAYING_CHANGED = "isPlayingChanged"
        private const val EVENT_POSITION_CHANGED = "positionChanged"
        private const val EVENT_BUFFER_CHANGED = "bufferChanged"
        private const val EVENT_PIP_CHANGED = "pipChanged"
        private const val EVENT_MUTE_CHANGED = "muteChanged"
        private const val EVENT_ERROR = "error"
    }
}
