package matsune.video_player

import android.net.Uri
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import java.io.IOException

class NoNetworkDataSource : DataSource {

    class Factory : DataSource.Factory {
        override fun createDataSource(): DataSource = NoNetworkDataSource()
    }

    override fun addTransferListener(transferListener: TransferListener) {
        // no-op (ネットワーク禁止のため転送は発生しない)
    }

    @Throws(IOException::class)
    override fun open(dataSpec: DataSpec): Long {
        throw IOException("Network is disabled for offline playback")
    }

    @Throws(IOException::class)
    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        throw IOException("Network is disabled for offline playback")
    }

    override fun getUri(): Uri? = null

    override fun close() { /* no-op */ }
}
