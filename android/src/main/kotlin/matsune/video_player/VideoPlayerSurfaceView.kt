package matsune.video_player

import android.content.Context
import android.util.Log
import android.view.SurfaceView

class VideoPlayerSurfaceView(context: Context): SurfaceView(context) {
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0

    fun setVideoSize(width: Int, height: Int) {
        videoWidth = width
        videoHeight = height
        requestLayout()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        if (videoWidth > 0 && videoHeight > 0) {
            var width = MeasureSpec.getSize(widthMeasureSpec)
            var height = MeasureSpec.getSize(heightMeasureSpec)
            val aspectRatio = videoWidth.toFloat() / videoHeight.toFloat()
            Log.d(VideoPlayerPlugin.TAG, "size: ${width}x${height}, aspect: ${videoWidth}x${videoHeight}")
            if (width > height * aspectRatio) {
                width = (height * aspectRatio).toInt()
            } else {
                height = (width / aspectRatio).toInt()
            }
            setMeasuredDimension(width, height)
        } else {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        }
    }
}