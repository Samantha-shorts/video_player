package matsune.video_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.database.DatabaseProvider
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.exoplayer.offline.*
import androidx.media3.exoplayer.scheduler.Requirements
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.IOException
import java.net.CookieHandler
import java.net.CookieManager
import java.net.CookiePolicy
import java.util.concurrent.Executors
import androidx.media3.common.C
import androidx.media3.exoplayer.drm.OfflineLicenseHelper
import androidx.media3.common.Format
import androidx.media3.exoplayer.drm.DrmSessionEventListener

object Downloader {
    private var dataSourceFactory: DataSource.Factory? = null
    private var httpDataSourceFactory: DataSource.Factory? = null
    private var databaseProvider: DatabaseProvider? = null
    private var downloadDirectory: File? = null
    private var downloadCache: Cache? = null
    private var downloadManager: DownloadManager? = null
    private var downloadIndex: DownloadIndex? = null
    private var downloadHelpers: HashMap<Uri, DownloadHelper> = hashMapOf()

    private val handler = Handler(Looper.getMainLooper())
    private val runnableMap: HashMap<Uri, Runnable> = hashMapOf()

    enum class Quality { LOW, MEDIUM, HIGH }

    var eventChannel: EventChannel? = null
        private set
    private val eventSink = QueuingEventSink()

    fun setupEventChannel(channel: EventChannel) {
        channel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink.setDelegate(sink)
            }

            override fun onCancel(arguments: Any?) {
                eventSink.setDelegate(null)
            }
        })
        eventChannel = channel
    }

    private fun sendEvent(event: String, params: Map<String, Any>? = null) {
        val result: MutableMap<String, Any> = params?.toMutableMap() ?: HashMap()
        result["event"] = event
        eventSink.success(result)
    }

    private fun buildRenderersFactory(context: Context): RenderersFactory {
        return DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
    }

    private fun getHttpDataSourceFactory(headers: Map<String, String>?): DataSource.Factory {
        val cookieManager = CookieManager()
        cookieManager.setCookiePolicy(CookiePolicy.ACCEPT_ORIGINAL_SERVER)
        CookieHandler.setDefault(cookieManager)
        httpDataSourceFactory = DefaultHttpDataSource.Factory().apply {
            headers?.let {
                setDefaultRequestProperties(it)
            }
        }
        return httpDataSourceFactory!!
    }

    private fun getDownloadManager(context: Context, headers: Map<String, String>?): DownloadManager {
        ensureDownloadManagerInitialized(context, headers)
        return downloadManager!!
    }

    private fun getDownloadCache(context: Context): Cache {
        if (downloadCache == null) {
            val downloadContentDirectory =
                File(getDownloadDirectory(context), DOWNLOAD_CONTENT_DIRECTORY)
            downloadCache = SimpleCache(
                downloadContentDirectory, NoOpCacheEvictor(), getDatabaseProvider(context)
            )
        }
        return downloadCache!!
    }

    fun getDataSourceFactory(context: Context): DataSource.Factory {
        if (dataSourceFactory == null) {
            val upstreamFactory = DefaultDataSource.Factory(
                context,
                getHttpDataSourceFactory(null)
            )
            dataSourceFactory = buildReadOnlyCacheDataSource(
                upstreamFactory,
                getDownloadCache(context)
            )
        }
        return dataSourceFactory!!
    }

    fun buildReadOnlyCacheDataSource(
        upstreamFactory: DataSource.Factory, cache: Cache
    ): CacheDataSource.Factory {
        return CacheDataSource.Factory()
            .setCache(cache)
            .setUpstreamDataSourceFactory(upstreamFactory)
            .setCacheWriteDataSinkFactory(null)
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    private fun getDatabaseProvider(context: Context): DatabaseProvider {
        if (databaseProvider == null) {
            databaseProvider = StandaloneDatabaseProvider(context)
        }
        return databaseProvider!!
    }

    private fun getDownloadDirectory(context: Context): File {
        if (downloadDirectory == null) {
            downloadDirectory = context.getExternalFilesDir( /* type= */null)
            if (downloadDirectory == null) {
                downloadDirectory = context.filesDir
            }
        }
        return downloadDirectory!!
    }

    private fun ensureDownloadManagerInitialized(context: Context, headers: Map<String, String>?) {
        if (downloadManager == null) {
            downloadManager = DownloadManager(
                context,
                getDatabaseProvider(context),
                getDownloadCache(context),
                getHttpDataSourceFactory(headers),
                Executors.newFixedThreadPool( /* nThreads= */6)
            )
            downloadIndex = downloadManager?.downloadIndex
            downloadManager?.resumeDownloads()
            downloadManager?.addListener(object : DownloadManager.Listener {
                override fun onDownloadChanged(
                    downloadManager: DownloadManager,
                    download: Download,
                    finalException: Exception?
                ) {
                    when (download.state) {
                        Download.STATE_DOWNLOADING -> {
                            startDownloadTimer(context, download)
                        }
                        Download.STATE_COMPLETED -> {
                            stopDownloadTimer(download)
                            val req = download.request
                            if (req.data == null || req.data!!.isEmpty()) {
                                sendEvent(DOWNLOAD_EVENT_ERROR,
                                    mapOf("error" to "Download finished without offline license (keySetId)."))
                            } else {
                                downloadHelpers.remove(req.uri)?.release()
                                val key = getKeyByDownloadId(context, req.id)!!
                                sendEvent(DOWNLOAD_EVENT_FINISHED, mapOf("key" to key))
                            }
                        }
                        Download.STATE_FAILED -> {
                            stopDownloadTimer(download)
                            downloadHelpers.remove(download.request.uri)?.release()
                        }
                        else -> {
                            stopDownloadTimer(download)
                        }
                    }
                }

                override fun onDownloadRemoved(
                    downloadManager: DownloadManager,
                    download: Download
                ) {
                    stopDownloadTimer(download)
                    downloadHelpers.remove(download.request.uri)?.release()
                }
            })
        }
    }

    fun startDownload(
        context: Context,
        key: String,
        url: String,
        headers: Map<String, String>?,
        widevineLicenseUrl: String?,
        quality: Quality,
    ) {
        val prefs = context.getSharedPreferences(PREFERENCES_KEY, Context.MODE_PRIVATE).edit()
        val drmReqHeaders = (headers ?: emptyMap()).toMutableMap()
        drmReqHeaders.putIfAbsent("Content-Type", "application/octet-stream")
        drmReqHeaders.putIfAbsent("Accept", "application/octet-stream")

        val httpFactory = DefaultHttpDataSource.Factory().apply {
            setAllowCrossProtocolRedirects(true)
            if (drmReqHeaders.isNotEmpty()) setDefaultRequestProperties(drmReqHeaders)
        }

        val baseMediaItemBuilder = MediaItem.Builder().setUri(url)

        if (!widevineLicenseUrl.isNullOrEmpty()) {
            val drmConf = MediaItem.DrmConfiguration.Builder(C.WIDEVINE_UUID)
                .setLicenseUri(widevineLicenseUrl)
                .setLicenseRequestHeaders(drmReqHeaders)
                .setMultiSession(false)
                .build()
            baseMediaItemBuilder.setDrmConfiguration(drmConf)
        }


        val mediaItem = baseMediaItemBuilder.build()
        val downloadManager = getDownloadManager(context, drmReqHeaders)
        val downloadHelper = DownloadHelper.forMediaItem(
            context,
            mediaItem,
            buildRenderersFactory(context),
            getHttpDataSourceFactory(drmReqHeaders)
        )

        downloadHelper.prepare(object : DownloadHelper.Callback {
            override fun onPrepared(helper: DownloadHelper) {
                // --- 既存の DRM ライセンス取得処理はそのまま ---
                val drmFormat: Format? = run {
                    for (periodIndex in 0 until helper.periodCount) {
                        val groups = helper.getTrackGroups(periodIndex)
                        for (g in 0 until groups.length) {
                            val group = groups.get(g)
                            for (i in 0 until group.length) {
                                val f = group.getFormat(i)
                                if (f.drmInitData != null) return@run f
                            }
                        }
                    }
                    null
                }

                var requestData: ByteArray? = null
                if (!widevineLicenseUrl.isNullOrEmpty() && drmFormat != null) {
                    try {
                        val licenseHelper = OfflineLicenseHelper.newWidevineInstance(
                            widevineLicenseUrl, false, httpFactory, drmReqHeaders,
                            DrmSessionEventListener.EventDispatcher()
                        )
                        val keySetId: ByteArray = licenseHelper.downloadLicense(drmFormat)
                        Log.i("Downloader", "★ keySetId acquired: bytes=${keySetId.size}, key=$key")
                        if (keySetId.isEmpty()) {
                            sendEvent(DOWNLOAD_EVENT_ERROR, mapOf(
                                "key" to key,
                                "error" to "Offline license (keySetId) is empty"
                            ))
                            licenseHelper.release()
                            return
                        }
                        licenseHelper.release()
                        requestData = keySetId
                    } catch (e: Exception) {
                        sendEvent(DOWNLOAD_EVENT_ERROR,
                            mapOf("error" to ("Offline license acquisition failed: ${e.message}")))
                        return
                    }
                }
                if (!widevineLicenseUrl.isNullOrEmpty() && (requestData == null || requestData!!.isEmpty())) {
                    sendEvent(DOWNLOAD_EVENT_ERROR,
                        mapOf("error" to "Offline license (keySetId) missing; aborting download"))
                    return
                }

                val streamKeys = mutableListOf<androidx.media3.common.StreamKey>()

                for (period in 0 until helper.periodCount) {
                    val groups = helper.getTrackGroups(period)

                    // (groupIndex, trackIndex, format) の候補を集める
                    val videoCandidates = mutableListOf<Triple<Int, Int, Format>>()
                    val audioCandidates = mutableListOf<Triple<Int, Int, Format>>() // ← 追加

                    for (g in 0 until groups.length) {
                        val group = groups.get(g)
                        for (t in 0 until group.length) {
                            val f = group.getFormat(t)
                            val mime = f.sampleMimeType ?: continue
                            when {
                                mime.startsWith("video") -> videoCandidates.add(Triple(g, t, f))
                                mime.startsWith("audio") -> audioCandidates.add(Triple(g, t, f)) // ← 追加
                            }
                        }
                    }

                    if (videoCandidates.isNotEmpty()) {
                        videoCandidates.sortBy { it.third.bitrate.takeIf { b -> b > 0 } ?: 0 }
                        val mid = (videoCandidates.size - 1) / 2
                        val pickVideo = when (quality) {
                            Quality.HIGH -> videoCandidates.last()
                            Quality.LOW -> videoCandidates.first()
                            Quality.MEDIUM -> videoCandidates[mid]
                        }
                        streamKeys.add(androidx.media3.common.StreamKey(period, pickVideo.first, pickVideo.second))
                    } else {
                        Log.w("Downloader", "No video formats found in period=$period; skipping video selection.")
                    }

                    if (audioCandidates.isNotEmpty()) {
                        val pickAudio = audioCandidates.maxByOrNull { triple ->
                            val f = triple.third
                            val defaultScore = if (f.selectionFlags and C.SELECTION_FLAG_DEFAULT != 0) 1 else 0
                            val langScore = if ((f.language ?: "").startsWith("ja", true)) 1 else 0
                            defaultScore * 1_000_000_000 + langScore * 1_000_000 + (f.bitrate.takeIf { it > 0 } ?: 0)
                        }!!
                        streamKeys.add(androidx.media3.common.StreamKey(period, pickAudio.first, pickAudio.second))
                    }
                }

                val request =
                    if (streamKeys.isNotEmpty()) {
                        val base = helper.getDownloadRequest(requestData)
                        DownloadRequest.Builder(base.id, base.uri)
                            .setMimeType(base.mimeType)
                            .setCustomCacheKey(base.customCacheKey)
                            .setData(base.data)
                            .setStreamKeys(streamKeys)
                            .build()
                    } else {
                        helper.getDownloadRequest(requestData)
                    }

                downloadHelpers[request.uri] = helper
                downloadManager.addDownload(request)

                val prefs = context.getSharedPreferences(PREFERENCES_KEY, Context.MODE_PRIVATE).edit()
                prefs.putString(key, request.id)
                prefs.apply()
            }

            override fun onPrepareError(helper: DownloadHelper, e: IOException) {
                Log.e("DownloadUtil", "onPrepareError", e)
                sendEvent(DOWNLOAD_EVENT_ERROR, mapOf("error" to (e.message ?: "prepare error")))
            }
        })
    }

    private fun startDownloadTimer(context: Context, download: Download) {
        val runnable = object : Runnable {
            override fun run() {
                // maybe called after download completed so check download is still going here
                if (downloadHelpers.containsKey(download.request.uri)) {
                    val progress = download.percentDownloaded / 100
                    var bytesDownloaded = download.bytesDownloaded
                    var bytesTotal = download.contentLength
                    val key = getKeyByDownloadId(context, download.request.id)!!
                    sendEvent(DOWNLOAD_EVENT_PROGRESS, mapOf("key" to key, "progress" to progress, "bytesDownloaded" to bytesDownloaded, "bytesTotal" to bytesTotal))
                    handler.postDelayed(this, 1000)
                } else {
                    stopDownloadTimer(download)
                }
            }
        }
        handler.post(runnable)
        runnableMap[download.request.uri] = runnable
    }

    private fun stopDownloadTimer(download: Download) {
        runnableMap.remove(download.request.uri)?.let {
            handler.removeCallbacks(it)
        }
    }

    fun removeDownload(context: Context, key: String) {
        ensureDownloadManagerInitialized(context, null)
        val prefs = context.getSharedPreferences(PREFERENCES_KEY, Context.MODE_PRIVATE)
        val editor = prefs.edit()

        prefs.getString(key, "")?.let { id ->
            val download = downloadIndex?.getDownload(id)
            val request = download?.request
            val mediaItem = request?.toMediaItem()
            val drmConf = mediaItem?.localConfiguration?.drmConfiguration

            val licenseUri = drmConf?.licenseUri?.toString()
            val keySetIdFromDrm = drmConf?.keySetId
            val keySetIdFromData = request?.data
            val keySetIdToRelease = keySetIdFromDrm ?: keySetIdFromData

            if (!licenseUri.isNullOrEmpty() && keySetIdToRelease != null) {
                try {
                    val licenseHelper = OfflineLicenseHelper.newWidevineInstance(
                        licenseUri,
                        false,
                        DefaultHttpDataSource.Factory(),
                        null,
                        DrmSessionEventListener.EventDispatcher()
                    )
                    licenseHelper.releaseLicense(keySetIdToRelease)
                    licenseHelper.release()
                } catch (e: Exception) {
                    Log.w("DownloadUtil", "releaseLicense failed", e)
                }
            }

            downloadManager?.removeDownload(id)
        }
        editor.remove(key)
        editor.apply()
    }

    fun getDownloadKeys(context: Context): List<String> {
        ensureDownloadManagerInitialized(context, null)
        val prefs = context.getSharedPreferences(PREFERENCES_KEY, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (entry in prefs.all) {
            val key = entry.key
            val id = entry.value as String
            val download = downloadIndex?.getDownload(id)
            when (download?.state) {
                Download.STATE_COMPLETED, Download.STATE_DOWNLOADING, Download.STATE_QUEUED, Download.STATE_RESTARTING, Download.STATE_STOPPED -> {}
                else -> {
                    editor.remove(key)
                }
            }
        }
        editor.apply()
        return prefs.all.keys.toList()
    }

    fun getDownloadByKey(context: Context, key: String): Download? {
        // まず初期化
        ensureDownloadManagerInitialized(context, null)

        val prefs = context.getSharedPreferences(PREFERENCES_KEY, Context.MODE_PRIVATE)
        val id = prefs.getString(key, null) ?: return null

        val d = downloadIndex?.getDownload(id)
        if (d == null) {
            // デバッグ用：インデックス内の id 一覧をログ
            val ids = mutableListOf<String>()
            val cursor = downloadIndex?.getDownloads()
            if (cursor != null) {
                try {
                    while (cursor.moveToNext()) {
                        val dl = cursor.getDownload() // ← プロパティではなくメソッドで取得
                        ids.add(dl.request.id)
                    }
                } finally {
                    cursor.close()
                }
            }
            Log.w(
                "Downloader",
                "Download not found for key=$key (id=$id); index has ids=${ids.joinToString()}"
            )
        }
        return d
    }

    fun getKeyByDownloadId(context: Context, id: String): String? {
        val prefs = context.getSharedPreferences(PREFERENCES_KEY, Context.MODE_PRIVATE)
        for (entry in prefs.all) {
            if (entry.value == id) {
                return entry.key
            }
        }
        return null
    }

    fun pauseDownload(context: Context, key: String) {
        getDownloadByKey(context, key)?.let {
            downloadManager?.setStopReason(it.request.id, DOWNLOAD_STOP_REASON_PAUSE)
            stopDownloadTimer(it)
            sendEvent(DOWNLOAD_EVENT_PAUSED, mapOf("key" to key))
        }
    }

    fun resumeDownload(context: Context, key: String) {
        getDownloadByKey(context, key)?.let {
            downloadManager?.setStopReason(it.request.id, Download.STOP_REASON_NONE)
            startDownloadTimer(context, it)
            sendEvent(DOWNLOAD_EVENT_RESUMED, mapOf("key" to key))
        }
    }

    fun cancelDownload(context: Context, key: String) {
        getDownloadByKey(context, key)?.let {
            downloadManager?.removeDownload(it.request.id)
            stopDownloadTimer(it)
            sendEvent(DOWNLOAD_EVENT_CANCELED, mapOf("key" to key))
        }
    }

    private const val PREFERENCES_KEY = "video_player_preferences"

    private const val DOWNLOAD_CONTENT_DIRECTORY = "downloads"

    private const val DOWNLOAD_EVENT_PROGRESS = "progress"
    private const val DOWNLOAD_EVENT_FINISHED = "finished"
    private const val DOWNLOAD_EVENT_CANCELED = "canceled"
    private const val DOWNLOAD_EVENT_PAUSED = "paused"
    private const val DOWNLOAD_EVENT_RESUMED = "resumed"
    private const val DOWNLOAD_EVENT_ERROR = "error"

    private const val DOWNLOAD_STOP_REASON_PAUSE = 1
}
