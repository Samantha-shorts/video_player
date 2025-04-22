package matsune.video_player

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi

class PipListener {
    private var isInPip = false
    private var pipHandler: Handler? = null
    private var pipRunnable: Runnable? = null

    @RequiresApi(Build.VERSION_CODES.N)
    fun startPictureInPictureListenerTimer(activity: Activity, player: VideoPlayerView) {
        pipHandler = Handler(Looper.getMainLooper())
        pipRunnable = Runnable {
            if (isInPip != activity.isInPictureInPictureMode) {
                if (!activity.isInPictureInPictureMode) {
                    // exited PiP
                    player.disposeMediaSession()
                    stopPipHandler()
                }
                player.onPictureInPictureStatusChanged(activity.isInPictureInPictureMode)
            }
            if (activity.isInPictureInPictureMode) {
                pipHandler?.postDelayed(pipRunnable!!, 100)
            }
            isInPip = activity.isInPictureInPictureMode
        }
        pipHandler?.post(pipRunnable!!)
    }

    fun stopPipHandler() {
        pipHandler?.removeCallbacksAndMessages(null)
        pipHandler = null
        pipRunnable = null
    }
}
