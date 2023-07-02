//
//  ArtworkManager.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/07/02.
//

import MediaPlayer

private protocol Artwork {
    var artwork: MPMediaItemArtwork { get }
}

private struct UrlArtwork: Artwork {
    let artwork: MPMediaItemArtwork
    let url: String
}

private struct ThumbnailArtwork: Artwork {
    let artwork: MPMediaItemArtwork
    let time: CMTime

    func stillValid(currentTime: CMTime, thumbnailRefreshSec: Int) -> Bool {
        let difference = CMTimeSubtract(time, currentTime)
        let diffInSec = Int(abs(CMTimeGetSeconds(difference)))
        return diffInSec < thumbnailRefreshSec
    }
}

class ArtworkManager {
    let thumbnailRefreshSec: Int
    private var caches: [TextureId: Artwork] = [:]
    private var isFetching = false

    init(thumbnailRefreshSec: Int) {
        self.thumbnailRefreshSec = thumbnailRefreshSec
    }

    func removeCache(textureId: TextureId) {
        caches.removeValue(forKey: textureId)
    }

    func fetchArtwork(
        textureId: Int, player: VideoPlayer, imageUrl: String?,
        result: @escaping (MPMediaItemArtwork?) -> Void
    ) {
        if let cache = caches[textureId] {
            // use cache if still valid
            if let cache = cache as? UrlArtwork, cache.url == imageUrl {
                result(cache.artwork)
                return
            } else if let cache = cache as? ThumbnailArtwork, imageUrl == nil,
                cache.stillValid(
                    currentTime: player.currentTime, thumbnailRefreshSec: thumbnailRefreshSec)
            {
                result(cache.artwork)
                return
            }
        }
        if isFetching {
            result(nil)
            return
        }
        isFetching = true
        // fetch artwork
        DispatchQueue.global().async { [weak self, weak player] in
            guard let self = self, let player = player else {
                self?.isFetching = false
                result(nil)
                return
            }
            var artwork: Artwork?
            if let imageUrl = imageUrl {
                artwork = fetchArtworkImageUrl(
                    textureId: textureId, player: player, imageUrl: imageUrl)
            } else {
                artwork = fetchArtworkThumbnail(textureId: textureId, player: player)
            }
            self.caches[textureId] = artwork
            self.isFetching = false
            result(artwork?.artwork)
        }

    }

    private func fetchArtworkImageUrl(textureId: Int, player: VideoPlayer, imageUrl: String)
        -> UrlArtwork?
    {
        var tempArtworkImage: UIImage?
        if !imageUrl.contains("http") {
            tempArtworkImage = UIImage(contentsOfFile: imageUrl)
        } else if let url = URL(string: imageUrl) {
            if let data = try? Data(contentsOf: url) {
                tempArtworkImage = UIImage(data: data)
            }
        }
        if let tempArtworkImage = tempArtworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: tempArtworkImage.size) { _ in
                tempArtworkImage
            }
            return UrlArtwork(artwork: artwork, url: imageUrl)
        }
        return nil
    }

    private func fetchArtworkThumbnail(textureId: Int, player: VideoPlayer) -> ThumbnailArtwork? {
        guard let playerItem = player.player.currentItem else {
            return nil
        }
        let time = playerItem.currentTime()
        if time < .zero || playerItem.duration < time {
            return nil
        }
        if playerItem.loadedTimeRanges.first?.timeRangeValue.containsTime(time) == true,
            player.videoOutput.hasNewPixelBuffer(forItemTime: time),
            let pixelBuffer = player.videoOutput.copyPixelBuffer(
                forItemTime: time, itemTimeForDisplay: nil)
        {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let uiImage = UIImage(ciImage: ciImage)
            let artwork = MPMediaItemArtwork(boundsSize: uiImage.size) { _ in uiImage }
            return ThumbnailArtwork(artwork: artwork, time: time)
        }
        return nil
    }
}
