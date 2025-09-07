package matsune.video_player

import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.database.DatabaseProvider
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.exoplayer.offline.*
import androidx.media3.exoplayer.drm.OfflineLicenseHelper
import androidx.media3.exoplayer.drm.DrmSessionEventListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.IOException
import java.net.CookieHandler
import java.net.CookieManager
import java.net.CookiePolicy
import java.util.concurrent.Executors
import android.media.MediaDrm

// --- ライセンスHTTPの詳細ログを出すFactory ---
// --- ライセンスHTTPの詳細ログを出すFactory ---
class LoggingHttpDataSourceFactory(
    private val base: DefaultHttpDataSource.Factory
) : HttpDataSource.Factory {

    override fun createDataSource(): HttpDataSource {
        val ds = base.createDataSource()
        return object : HttpDataSource by ds {
            override fun open(dataSpec: DataSpec): Long {
                val r = ds.open(dataSpec)
                val headers = ds.responseHeaders
                val ct = headers["Content-Type"]?.joinToString()
                val code = headers[":status"]?.firstOrNull() ?: "unknown"
                Log.d("WV-LIC", "OPEN ${dataSpec.uri} -> code=$code, CT=$ct, reqLen=${dataSpec.length}")
                return r
            }

            override fun read(buffer: ByteArray, offset: Int, readLength: Int): Int {
                val n = ds.read(buffer, offset, readLength)
                if (n > 0) {
                    val preview = buffer.copyOfRange(offset, offset + minOf(n, 64))
                    val ascii = buildString {
                        preview.forEach {
                            val c = it.toInt() and 0xFF
                            append(if (c in 32..126) c.toChar() else '.')
                        }
                    }
                    Log.d("WV-LIC", "READ $n bytes; head(ascii)=\"$ascii\"")
                }
                return n
            }
        }
    }

    // --- 必須メソッドは base に委譲 ---
    override fun setDefaultRequestProperties(defaultRequestProperties: Map<String, String>): HttpDataSource.Factory {
        base.setDefaultRequestProperties(defaultRequestProperties)
        return this
    }
}

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

    private fun newHttpDataSourceFactory(headers: Map<String, String>?): DefaultHttpDataSource.Factory {
        val cookieManager = CookieManager()
        cookieManager.setCookiePolicy(CookiePolicy.ACCEPT_ORIGINAL_SERVER)
        CookieHandler.setDefault(cookieManager)
        return DefaultHttpDataSource.Factory().apply {
            headers?.let { setDefaultRequestProperties(it) }
            setAllowCrossProtocolRedirects(true)
            setConnectTimeoutMs(15_000)
            setReadTimeoutMs(30_000)
        }
    }

    private fun getHttpDataSourceFactory(headers: Map<String, String>?): DataSource.Factory {
        if (httpDataSourceFactory == null) {
            httpDataSourceFactory = newHttpDataSourceFactory(headers)
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
    ): CacheDataSource.Factory? {
        return CacheDataSource.Factory()
            .setCache(cache)
            .setUpstreamDataSourceFactory(upstreamFactory)
            .setCacheWriteDataSinkFactory(null)
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    fun getOfflineOnlyDataSourceFactory(context: Context): DataSource.Factory {
        val cache = getDownloadCache(context)
        val upstream = NoNetworkDataSource.Factory()
        return CacheDataSource.Factory()
            .setCache(cache)
            .setUpstreamDataSourceFactory(upstream)
            .setCacheWriteDataSinkFactory(null)
    }

    private fun getDatabaseProvider(context: Context): DatabaseProvider {
        if (databaseProvider == null) {
            databaseProvider = StandaloneDatabaseProvider(context)
        }
        return databaseProvider!!
    }

    private fun getDownloadDirectory(context: Context): File {
        if (downloadDirectory == null) {
            downloadDirectory = context.getExternalFilesDir(/* type= */ null)
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
                Executors.newFixedThreadPool(/* nThreads= */ 6)
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
                            downloadHelpers.remove(download.request.uri)?.release()
                            val key = getKeyByDownloadId(context, download.request.id)!!
                            sendEvent(DOWNLOAD_EVENT_FINISHED, mapOf("key" to key))
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
    ) {
        val prefs = context.getSharedPreferences(PREFERENCES_KEY, Context.MODE_PRIVATE).edit()

        // --- コンテンツ(マニフェスト/セグメント)用 HTTP Factory ---
        val contentHeaders = headers ?: emptyMap()
        val contentHttpFactory = DefaultHttpDataSource.Factory()
            .setDefaultRequestProperties(contentHeaders)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(30_000)

        val downloadManager = getDownloadManager(context, headers)

        // 端末のセキュリティレベルを参考ログとして出す
        logWidevineSecurityLevel()

        val mediaItemBuilder = MediaItem.Builder().setUri(url)
        if (!widevineLicenseUrl.isNullOrEmpty()) {
            val drmHeaders = HashMap<String, String>().apply {
                put("Content-Type", "application/octet-stream")
                put("Accept", "application/octet-stream")
                putAll(contentHeaders) // Authorization/Cookie/Originなどを引き継ぐ
            }
            val drmConf = MediaItem.DrmConfiguration.Builder(C.WIDEVINE_UUID)
                .setLicenseUri(widevineLicenseUrl)
                .setLicenseRequestHeaders(drmHeaders)
                .setMultiSession(false)
                .setForceDefaultLicenseUri(true)
                .build()
            mediaItemBuilder.setDrmConfiguration(drmConf)
        }

        val mediaItem = mediaItemBuilder.build()

        val downloadHelper = DownloadHelper.forMediaItem(
            context,
            mediaItem,
            buildRenderersFactory(context),
            contentHttpFactory // コンテンツ用
        )

        downloadHelper.prepare(object : DownloadHelper.Callback {
            override fun onPrepared(helper: DownloadHelper) {
                var requestData: ByteArray? = null

                // --- ライセンス(オフライン)取得 ---
                if (!widevineLicenseUrl.isNullOrEmpty()) {
                    try {
                        val drmFormat: Format? = findFirstDrmFormat(helper, url)
                        if (drmFormat == null) {
                            Log.e("Downloader", "No drmInitData found in tracks for $url")
                        } else {
                            // ライセンスHTTPは octet-stream & ログ出力付き
                            val licHeaders = HashMap<String, String>().apply {
                                put("Content-Type", "application/octet-stream")
                                put("Accept", "application/octet-stream")
                                putAll(contentHeaders)
                            }
                            val licenseHttpBase = DefaultHttpDataSource.Factory()
                                .setDefaultRequestProperties(licHeaders)
                                .setAllowCrossProtocolRedirects(true)
                                .setConnectTimeoutMs(15_000)
                                .setReadTimeoutMs(30_000)
                            val licenseHttpFactory: HttpDataSource.Factory =
                                LoggingHttpDataSourceFactory(licenseHttpBase)

                            val licenseHelper = OfflineLicenseHelper.newWidevineInstance(
                                widevineLicenseUrl,
                                /* forceDefaultLicenseUrl = */ false,
                                licenseHttpFactory,
                                null,
                                DrmSessionEventListener.EventDispatcher()
                            )
                            try {
                                val keySetId = licenseHelper.downloadLicense(drmFormat)
                                if (keySetId.isNotEmpty()) {
                                    requestData = keySetId
                                    Log.i("Downloader", "Offline license acquired: ${keySetId.size} bytes")
                                } else {
                                    Log.e("Downloader", "Offline keySetId is empty for $url (persistent disabled?)")
                                }
                            } finally {
                                licenseHelper.release()
                            }
                        }
                    } catch (e: HttpDataSource.InvalidResponseCodeException) {
                        dumpLicenseHttpError(e, widevineLicenseUrl ?: url)
                    } catch (e: IOException) {
                        Log.e(
                            "Downloader",
                            "License IO error for $url: ${e.javaClass.simpleName}: ${e.message}"
                        )
                    } catch (e: Exception) {
                        Log.e(
                            "Downloader",
                            "Offline license acquisition failed: ${e.javaClass.simpleName}: ${e.message}"
                        )
                    }
                }

                // ライセンス取得失敗時はDLを開始しない
                if (!widevineLicenseUrl.isNullOrEmpty() && (requestData == null || requestData.isEmpty())) {
                    Log.e("Downloader", "Offline license acquisition failed for $url; not starting download")
                    sendEvent(DOWNLOAD_EVENT_ERROR, mapOf("key" to key, "error" to "offline_license_missing"))
                    helper.release()
                    return
                }

                val request = helper.getDownloadRequest(requestData)

                // Save key->id mapping first to avoid race
                prefs.putString(key, request.id)
                prefs.apply()

                downloadHelpers[request.uri] = helper
                downloadManager.addDownload(request)
            }

            override fun onPrepareError(helper: DownloadHelper, e: IOException) {
                Log.e("Downloader", "onPrepareError url?=${mediaItemUriSafe(mediaItem)}", e)
                sendEvent(
                    DOWNLOAD_EVENT_ERROR,
                    mapOf("key" to key, "error" to (e.localizedMessage ?: "prepare_error"))
                )
            }
        })
    }

    private fun findFirstDrmFormat(helper: DownloadHelper, url: String): Format? {
        for (period in 0 until helper.periodCount) {
            val groups = helper.getTrackGroups(period)
            for (g in 0 until groups.length) {
                val group = groups.get(g)
                for (i in 0 until group.length) {
                    val f = group.getFormat(i)
                    if (f.drmInitData != null) {
                        Log.d(
                            "Downloader",
                            "Found drmInitData: sampleMimeType=${f.sampleMimeType}, codecs=${f.codecs}, width=${f.width}, height=${f.height}"
                        )
                        return f
                    }
                }
            }
        }
        Log.w("Downloader", "No drmInitData in any track groups for $url")
        return null
    }

    private fun mediaItemUriSafe(item: MediaItem): String? = try {
        item.localConfiguration?.uri?.toString()
    } catch (_: Throwable) { null }

    private fun logWidevineSecurityLevel() {
        try {
            val uuid = C.WIDEVINE_UUID
            val md = MediaDrm(uuid)
            val level = md.getPropertyString("securityLevel")
            val vendor = md.getPropertyString("vendor")
            val version = md.getPropertyString("version")
            Log.i("Downloader", "Widevine securityLevel=$level vendor=$vendor version=$version sdk=${Build.VERSION.SDK_INT}")
            md.release()
        } catch (e: Exception) {
            Log.w("Downloader", "MediaDrm info unavailable: ${e.message}")
        }
    }

    // --- HTTP 4xx/5xxなどの応答を詳細に出す ---
    private fun dumpLicenseHttpError(e: HttpDataSource.InvalidResponseCodeException, url: String) {
        val code = e.responseCode
        val headers = e.headerFields?.entries?.joinToString { (k, v) -> "$k=${v?.joinToString()}" }
        val body = e.responseBody
        val bodyPreviewAscii = if (body != null) {
            val len = minOf(body.size, 256)
            buildString {
                for (i in 0 until len) {
                    val c = body[i].toInt() and 0xFF
                    append(if (c in 32..126) c.toChar() else '.')
                }
            }
        } else "(null)"
        val bodyB64 = if (body != null) Base64.encodeToString(body, Base64.NO_WRAP) else "(null)"
        Log.e("Downloader", "License HTTP $code for $url; headers=$headers")
        Log.e("Downloader", "License body(head, ascii)=\"$bodyPreviewAscii\"")
        Log.e("Downloader", "License body(base64)=$bodyB64")
    }

    private fun startDownloadTimer(context: Context, download: Download) {
        val runnable = object : Runnable {
            override fun run() {
                if (downloadHelpers.containsKey(download.request.uri)) {
                    val progress = download.percentDownloaded / 100 // 0.0..1.0
                    val key = getKeyByDownloadId(context, download.request.id)!!
                    val bytesDownloaded = download.bytesDownloaded
                    val bytesTotal = download.contentLength
                    sendEvent(
                        DOWNLOAD_EVENT_PROGRESS,
                        mapOf(
                            "key" to key,
                            "progress" to progress,
                            "bytesDownloaded" to bytesDownloaded,
                            "bytesTotal" to bytesTotal,
                        )
                    )
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
        prefs.getString(key, "")?.let {
            downloadManager?.removeDownload(it)
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
        val prefs = context.getSharedPreferences(PREFERENCES_KEY, Context.MODE_PRIVATE)
        ensureDownloadManagerInitialized(context, null)
        return prefs.getString(key, "")?.let { downloadIndex?.getDownload(it) }
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
