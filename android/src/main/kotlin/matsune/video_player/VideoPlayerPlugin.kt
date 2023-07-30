package matsune.video_player

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.LongSparseArray
import androidx.media3.datasource.cache.*
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.offline.*
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry


/** VideoPlayerPlugin */
class VideoPlayerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private val videoPlayers = LongSparseArray<VideoPlayer>()
  private val dataSources = LongSparseArray<Map<String, Any?>>()
  private var flutterState: FlutterState? = null
  private var activity: Activity? = null
  private var pipHandler: Handler? = null
  private var pipRunnable: Runnable? = null
  private var currentNotificationTextureId: Long? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    flutterState =
        FlutterState(binding.applicationContext, binding.binaryMessenger, binding.textureRegistry)
    flutterState?.startListening(this)

    if (Downloader.eventChannel == null) {
      Downloader.setupEventChannel(
        EventChannel(flutterState?.binaryMessenger, DOWNLOAD_EVENTS_CHANNEL)
      )
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    disposeAllPlayers()
    flutterState?.stopListening()
    flutterState = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

  override fun onDetachedFromActivity() {}

  private fun disposeAllPlayers() {
    for (i in 0 until videoPlayers.size()) {
      videoPlayers.valueAt(i).dispose()
    }
    videoPlayers.clear()
    dataSources.clear()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (flutterState == null || flutterState?.textureRegistry == null) {
      result.error("no_activity", "better_player plugin requires a foreground activity", null)
      return
    }
    when (call.method) {
      METHOD_INIT -> {
        disposeAllPlayers()
        result.success(null)
      }
      METHOD_CREATE -> {
        val textureEntry = flutterState!!.textureRegistry!!.createSurfaceTexture()
        val textureId = textureEntry.id()
        val eventChannel = EventChannel(flutterState?.binaryMessenger, EVENTS_CHANNEL + textureId)
        var customDefaultLoadControl = CustomDefaultLoadControl()
        if (call.hasArgument("minBufferMs") &&
                call.hasArgument("maxBufferMs") &&
                call.hasArgument("bufferForPlaybackMs") &&
                call.hasArgument("bufferForPlaybackAfterRebufferMs")
        ) {
          customDefaultLoadControl =
              CustomDefaultLoadControl(
                  call.argument("minBufferMs"),
                  call.argument("maxBufferMs"),
                  call.argument("bufferForPlaybackMs"),
                  call.argument("bufferForPlaybackAfterRebufferMs")
              )
        }
        val player =
            VideoPlayer(
                flutterState?.applicationContext!!,
                eventChannel,
                textureEntry,
                customDefaultLoadControl,
            )
        videoPlayers.put(textureId, player)
        result.success(mapOf("textureId" to textureId))
      }
      METHOD_IS_PICTURE_IN_PICTURE_SUPPORTED -> {
        result.success(mapOf("isPictureInPictureSupported" to isPictureInPictureSupported()))
      }
      METHOD_DOWNLOAD_OFFLINE_ASSET -> {
        val key = call.argument<String>("key")!!
        val uri = call.argument<String>("uri")!!
        val headers: Map<String, String>? = call.argument<Map<String,String>>("headers")
        val context = flutterState?.applicationContext!!
        Downloader.startDownload(context, key, uri, headers)
        result.success(null)
      }
      METHOD_DELETE_OFFLINE_ASSET -> {
        val context = flutterState?.applicationContext!!
        val key = call.argument<String>("key")!!
        Downloader.removeDownload(context, key)
        result.success(null)
      }
      METHOD_GET_DOWNLOADS -> {
        val context = flutterState?.applicationContext!!
        val keys = Downloader.getDownloadKeys(context)
        var res = mutableMapOf<String, Map<String, Any>>()
        keys.forEach {
          val key = it
          val download = Downloader.getDownloadByKey(context, key)
          when (download?.state) {
            Download.STATE_COMPLETED -> {
              res[key] = mapOf("state" to DOWNLOAD_STATE_COMPLETED)
            }
            Download.STATE_DOWNLOADING, Download.STATE_QUEUED, Download.STATE_RESTARTING -> {
              res[key] = mapOf("state" to DOWNLOAD_STATE_RUNNING)
            }
            else -> {
              res[key] = mapOf("state" to DOWNLOAD_STATE_CANCELING)
            }
          }
        }
        result.success(res)
      }
      else -> {
        val textureId = (call.argument<Any>("textureId") as Number?)!!.toLong()
        val player = videoPlayers[textureId]
        if (player == null) {
          result.error(
              "Unknown textureId",
              "No video player associated with texture id $textureId",
              null
          )
          return
        }
        onPlayerMethodCall(call, result, textureId, player)
      }
    }
  }

  private fun onPlayerMethodCall(
      call: MethodCall,
      result: MethodChannel.Result,
      textureId: Long,
      player: VideoPlayer
  ) {
    when (call.method) {
      METHOD_SET_DATA_SOURCE -> {
        setDataSource(call, textureId, player)
        result.success(null)
      }
      METHOD_PLAY -> {
        setupNotification(textureId, player)
        player.play()
        result.success(null)
      }
      METHOD_PAUSE -> {
        player.pause()
        result.success(null)
      }
      METHOD_SEEK_TO -> {
        val location = (call.argument("position") as Number?)!!.toInt()
        player.seekTo(location)
        result.success(null)
      }
      METHOD_DISPOSE -> {
        dispose(player, textureId)
        result.success(null)
      }
      METHOD_WILL_EXIT_FULLSCREEN -> {}
      METHOD_ENABLE_PICTURE_IN_PICTURE -> {
        enablePictureInPicture(player)
        result.success(null)
      }
      METHOD_DISABLE_PICTURE_IN_PICTURE -> {
        disablePictureInPicture(player)
        result.success(null)
      }
      METHOD_SET_MUTED -> {
        player.isMuted = call.argument("muted")!!
        result.success(null)
      }
      METHOD_SET_PLAYBACK_RATE -> {
        val rate = (call.argument("rate") as Number?)!!.toFloat()
        player.playbackSpeed = rate
        result.success(null)
      }
      METHOD_SET_TRACK_PARAMETERS -> {
        val width = (call.argument("width") as Number?)!!.toInt()
        val height = (call.argument("height") as Number?)!!.toInt()
        val bitrate = (call.argument("bitrate") as Number?)!!.toInt()
        player.setTrackParameters(width, height, bitrate)
        result.success(null)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun setupNotification(textureId: Long, player: VideoPlayer) {
    try {
      if (textureId == currentNotificationTextureId) {
        return
      }
      val dataSource = dataSources[textureId]
      currentNotificationTextureId = textureId
      removeOtherNotificationListeners()
      val title = getParameter(dataSource, "title", "")
      val author = getParameter(dataSource, "author", "")
      val imageUrl = getParameter(dataSource, "imageUrl", "")
      val notificationChannelName =
          getParameter<String?>(dataSource, "notificationChannelName", null)
      val activityName = getParameter(dataSource, "activityName", "MainActivity")
      player.setupPlayerNotification(
          flutterState?.applicationContext!!,
          title,
          author,
          imageUrl,
          notificationChannelName,
          activityName
      )
    } catch (exception: Exception) {
      Log.e(TAG, "SetupNotification failed", exception)
    }
  }

  private fun removeOtherNotificationListeners() {
    for (index in 0 until videoPlayers.size()) {
      videoPlayers.valueAt(index).disposeRemoteNotifications()
    }
  }

  @Suppress("UNCHECKED_CAST")
  private fun <T> getParameter(parameters: Map<String, Any?>?, key: String, defaultValue: T): T {
    if (parameters?.containsKey(key) == true) {
      val value = parameters[key]
      if (value != null) {
        return value as T
      }
    }
    return defaultValue
  }

  private fun setDataSource(call: MethodCall, textureId: Long, player: VideoPlayer) {
    val dataSource = call.argument<Map<String, Any?>>("dataSource")!!
    dataSources.put(textureId, dataSource)
    val offline = getParameter(dataSource, "offline", false)
    if (offline) {
      val offlineKey = getParameter(dataSource, "key", "")
      player.setOfflineDataSource(offlineKey)
    } else {
      val headers: Map<String, String> = getParameter(dataSource, "headers", HashMap())
      val uri = getParameter(dataSource, "uri", "")
      player.setNetworkDataSource(uri, headers)
    }
  }

  private fun dispose(player: VideoPlayer, textureId: Long) {
    stopPipHandler()
    player.dispose()
    videoPlayers.remove(textureId)
    dataSources.remove(textureId)
  }

  private val isAndroidOreoOrHigher: Boolean
    get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

  private val isAndroidNougatOrHigher: Boolean
    get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

  private fun isPictureInPictureSupported(): Boolean {
    return isAndroidOreoOrHigher &&
        activity?.packageManager?.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE) ==
            true
  }

  private fun enablePictureInPicture(player: VideoPlayer) {
    if (isAndroidOreoOrHigher) {
      player.setupMediaSession(flutterState!!.applicationContext)
      activity!!.enterPictureInPictureMode(PictureInPictureParams.Builder().build())
      startPictureInPictureListenerTimer(player)
    }
  }

  private fun disablePictureInPicture(player: VideoPlayer) {
    stopPipHandler()
    activity!!.moveTaskToBack(false)
    player.disposeMediaSession()
  }

  private var isInPip = false

  private fun startPictureInPictureListenerTimer(player: VideoPlayer) {
    if (isAndroidNougatOrHigher) {
      pipHandler = Handler(Looper.getMainLooper())
      pipRunnable = Runnable {
        if (isInPip != activity!!.isInPictureInPictureMode) {
          if (!activity!!.isInPictureInPictureMode) {
            // exited PiP
            player.disposeMediaSession()
            stopPipHandler()
          }
          player.onPictureInPictureStatusChanged(activity!!.isInPictureInPictureMode)
        }
        if (activity!!.isInPictureInPictureMode) {
          pipHandler?.postDelayed(pipRunnable!!, 100)
        }
        isInPip = activity!!.isInPictureInPictureMode
      }
      pipHandler?.post(pipRunnable!!)
    }
  }

  private fun stopPipHandler() {
    pipHandler?.removeCallbacksAndMessages(null)
    pipHandler = null
    pipRunnable = null
  }

  private class FlutterState(
      val applicationContext: Context,
      val binaryMessenger: BinaryMessenger,
      val textureRegistry: TextureRegistry?
  ) {
    private val methodChannel: MethodChannel = MethodChannel(binaryMessenger, CHANNEL)

    fun startListening(methodCallHandler: MethodCallHandler?) {
      methodChannel.setMethodCallHandler(methodCallHandler)
    }

    fun stopListening() {
      methodChannel.setMethodCallHandler(null)
    }
  }

  companion object {
    private const val TAG = "VideoPlayerPlugin"
    private const val CHANNEL = "video_player"
    private const val EVENTS_CHANNEL = "video_player_channel/videoEvents"
    private const val DOWNLOAD_EVENTS_CHANNEL = "video_player_channel/downloadEvents"

    private const val METHOD_INIT = "init"
    private const val METHOD_CREATE = "create"
    private const val METHOD_IS_PICTURE_IN_PICTURE_SUPPORTED = "isPictureInPictureSupported"
    private const val METHOD_SET_DATA_SOURCE = "setDataSource"
    private const val METHOD_PLAY = "play"
    private const val METHOD_PAUSE = "pause"
    private const val METHOD_SEEK_TO = "seekTo"
    private const val METHOD_DISPOSE = "dispose"
    private const val METHOD_WILL_EXIT_FULLSCREEN = "willExitFullscreen"
    private const val METHOD_ENABLE_PICTURE_IN_PICTURE = "enablePictureInPicture"
    private const val METHOD_DISABLE_PICTURE_IN_PICTURE = "disablePictureInPicture"
    private const val METHOD_SET_MUTED = "setMuted"
    private const val METHOD_SET_PLAYBACK_RATE = "setPlaybackRate"
    private const val METHOD_SET_TRACK_PARAMETERS = "setTrackParameters"
    private const val METHOD_DOWNLOAD_OFFLINE_ASSET = "downloadOfflineAsset"
    private const val METHOD_DELETE_OFFLINE_ASSET = "deleteOfflineAsset"
    private const val METHOD_GET_DOWNLOADS = "getDownloads"

    private const val DOWNLOAD_STATE_RUNNING = 0
    private const val DOWNLOAD_STATE_SUSPENDED = 1
    private const val DOWNLOAD_STATE_CANCELING = 2
    private const val DOWNLOAD_STATE_COMPLETED = 3
  }
}
