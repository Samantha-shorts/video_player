package matsune.video_player


import android.content.Context
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import androidx.media3.common.*
import androidx.media3.common.C.AUDIO_CONTENT_TYPE_MOVIE
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.*
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView

class VideoPlayerView(
    private val context: Context,
    private val eventChannel: EventChannel,
    private val videoPlayer: VideoPlayer
) : PlatformView {
    private val playerView: PlayerView = PlayerView(context)
    private val surfaceOwnerToken = Any()

    init {
        playerView.useController = false
        playerView.player = videoPlayer.exoPlayer
        setupVideoPlayer(eventChannel)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        videoPlayer.clearVideoSurface(surfaceOwnerToken)
        eventChannel.setStreamHandler(null)
        playerView.player = null
    }

    private fun setupVideoPlayer(eventChannel: EventChannel) {
        val surfaceView = playerView.videoSurfaceView
        if (surfaceView is SurfaceView) {
            val holder = surfaceView.holder
            val surface = holder.surface
            if (surface != null && surface.isValid) {
                videoPlayer.bindVideoSurface(surfaceOwnerToken, surface)
                val currentPosition = videoPlayer.exoPlayer.currentPosition
                val mediaItem = videoPlayer.exoPlayer.currentMediaItem
                videoPlayer.exoPlayer.setMediaItem(mediaItem!!, currentPosition)
                videoPlayer.exoPlayer.prepare()
            }

            holder.addCallback(object : SurfaceHolder.Callback {
                override fun surfaceCreated(holder: SurfaceHolder) {
                    if (videoPlayer.exoPlayer.applicationLooper.thread.isAlive) {
                        videoPlayer.bindVideoSurface(surfaceOwnerToken, holder.surface)
                    } else {
                        Log.e(TAG, "Surface created, but ExoPlayer is already released.")
                    }
                }
                override fun surfaceDestroyed(holder: SurfaceHolder) {
                    videoPlayer.clearVideoSurface(surfaceOwnerToken)
                    try {
                        surfaceView.holder.surface.release()
                    } catch (_: Throwable) {}
                }
                override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) = Unit
            })
        }
        videoPlayer.exoPlayer.setAudioAttributes(
            AudioAttributes.Builder().setContentType(AUDIO_CONTENT_TYPE_MOVIE).build(),
            true
        )
        videoPlayer.exoPlayer.addListener(
            object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_BUFFERING -> {
                            // no-op
                        }
                        Player.STATE_READY -> {
                            if (!videoPlayer.isInitialized) {
                                videoPlayer.setInitialized()
                                return
                            }
                        }
                        Player.STATE_ENDED -> {
                            videoPlayer.pause()
                            videoPlayer.sendEvent(EVENT_ENDED)
                        }
                        Player.STATE_IDLE -> {
                            // no-op
                        }
                    }
                    videoPlayer.sendEvent(EVENT_ON_PLAYBACK_STATE_CHANGED, mapOf("state" to playbackState))
                }

                override fun onPlayerError(error: PlaybackException) {
                    var invalid = false
                    val sb = StringBuilder()
                    sb.append("PlaybackException: ")
                        .append(error.errorCodeName)
                        .append(" (").append(error.errorCode).append(")")
                        .append(": ")
                        .append(error.message ?: "")

                    var cause: Throwable? = error.cause
                    var level = 0
                    while (cause != null && level < 5) {
                        sb.append("\ncaused by [").append(level).append("]: ")
                            .append(cause::class.java.simpleName)
                            .append(": ")
                            .append(cause.message ?: "")
                        if (cause is HttpDataSource.InvalidResponseCodeException) {
                            if (cause.responseCode == 403) invalid = true
                        }
                        cause = cause.cause
                        level++
                    }

                    Log.e(TAG, "onPlayerError: ${sb.toString()}")
                    videoPlayer.sendEvent(
                        EVENT_ERROR,
                        mapOf(
                            "error" to sb.toString(),
                            "invalid" to invalid,
                            "code" to error.errorCode
                        )
                    )
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    if (isPlaying) {
                        videoPlayer.handler.post(videoPlayer.runnable)

                        if (!videoPlayer.isBufferingRunnableStarted) {
                            videoPlayer.handler.post(videoPlayer.bufferingRunnable)
                            videoPlayer.isBufferingRunnableStarted = true
                        }
                    } else {
                        videoPlayer.handler.removeCallbacks(videoPlayer.runnable)
                    }
                    videoPlayer.sendEvent(EVENT_IS_PLAYING_CHANGED, mapOf("isPlaying" to isPlaying))
                }

                override fun onVolumeChanged(volume: Float) {
                    videoPlayer.sendEvent(EVENT_MUTE_CHANGED, mapOf("isMuted" to (volume == 0f)))
                }
            }
        )
    }

    companion object {
        private const val TAG = "VideoPlayer"

        private const val EVENTS_CHANNEL = "video_player_channel/videoEvents"
        private const val EVENT_INITIALIZED = "initialized"
        private const val EVENT_ON_PLAYBACK_STATE_CHANGED = "onPlaybackStateChanged"
        private const val EVENT_IS_PLAYING_CHANGED = "isPlayingChanged"
        private const val EVENT_POSITION_CHANGED = "positionChanged"
        private const val EVENT_BUFFER_CHANGED = "bufferChanged"
        private const val EVENT_PIP_CHANGED = "pipChanged"
        private const val EVENT_MUTE_CHANGED = "muteChanged"
        private const val EVENT_ENDED = "ended"
        private const val EVENT_ERROR = "error"

        private const val DEFAULT_NOTIFICATION_CHANNEL = "VIDEO_PLAYER_NOTIFICATION"
        private const val NOTIFICATION_ID = 10000
    }
}
