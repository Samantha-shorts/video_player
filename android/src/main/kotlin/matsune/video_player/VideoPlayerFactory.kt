package matsune.video_player

import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class VideoPlayerFactory(
    private val context: Context,
    private val eventChannel: EventChannel,
    private val videoPlayer: VideoPlayer,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return VideoPlayerView(
            context,
            eventChannel,
            videoPlayer,
        )
    }
}
