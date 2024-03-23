package matsune.video_player

import android.content.Context
import android.util.DisplayMetrics
import android.util.Log
import android.view.SurfaceView
import android.view.WindowManager

class VideoPlayerSurfaceView(context: Context): SurfaceView(context) {
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0

    private var expandedVideoWidth: Int = 0
    private var expandedVideoHeight: Int = 0
    private var isExpanded: Boolean = false

    fun setVideoSize(width: Int, height: Int) {
        videoWidth = width
        videoHeight = height
        requestLayout()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        if ((videoWidth > 0 && videoHeight > 0) || (isExpanded && expandedVideoWidth > 0 && expandedVideoHeight > 0)) {
            var width = MeasureSpec.getSize(widthMeasureSpec)
            var height = MeasureSpec.getSize(heightMeasureSpec)
            val aspectRatio = videoWidth.toFloat() / videoHeight.toFloat()
            Log.d(VideoPlayerPlugin.TAG, "size: ${width}x${height}, aspect: ${videoWidth}x${videoHeight}")
            if (isExpanded) {
                width = expandedVideoWidth
                height = expandedVideoHeight
            } else if (width > height * aspectRatio) {
                width = (height * aspectRatio).toInt()
            } else {
                height = (width / aspectRatio).toInt()
            }
            setMeasuredDimension(width, height)
        } else {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        }
    }

    fun expand() {
        isExpanded = true
        val screenWidth = getScreenWidth(context)
        val aspectRatio = videoHeight.toFloat() / videoWidth.toFloat()
        expandedVideoWidth = screenWidth
        expandedVideoHeight = (screenWidth * aspectRatio).toInt()
        requestLayout()
    }

    fun shrink() {
        isExpanded = false
        requestLayout()
    }

    private fun getScreenWidth(context: Context): Int {
        val metrics = DisplayMetrics()
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            val display = context.display
            display?.getMetrics(metrics)
        } else {
            @Suppress("DEPRECATION")
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val display = windowManager.defaultDisplay
            @Suppress("DEPRECATION")
            display.getMetrics(metrics)
        }
        return metrics.widthPixels
    }
}
