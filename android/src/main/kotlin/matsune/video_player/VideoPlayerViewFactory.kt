package matsune.video_player

import android.content.Context
import android.util.LongSparseArray
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class VideoPlayerViewFactory(private val videoPlayers: LongSparseArray<VideoPlayer>) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>
        val textureId = (creationParams["textureId"] as Int).toLong()
        val videoPlayer = videoPlayers[textureId]
        return VideoPlayerView(context, videoPlayer)
    }
}