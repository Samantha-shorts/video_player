package matsune.video_player

import android.content.Context
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView

internal class VideoPlayerView(context: Context, private val videoPlayer: VideoPlayer) : PlatformView {
    private val view: FrameLayout
    private val surfaceView: VideoPlayerSurfaceView

    override fun getView(): View {
        if (videoPlayer.surfaceView != surfaceView) {
            videoPlayer.surfaceView = surfaceView
        }
        return view
    }

    override fun dispose() {}

    init {
        view = FrameLayout(context)
        surfaceView = VideoPlayerSurfaceView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
        }
        view.addView(surfaceView)
    }
}