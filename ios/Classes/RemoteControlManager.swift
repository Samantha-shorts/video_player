//
//  RemoteControlManager.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/07/31.
//

import AVKit
import MediaPlayer

class RemoteControlManager {
    private var remotePlayer: VideoPlayer?
//    private let artworkManager = ArtworkManager(thumbnailRefreshSec: 60)
    private var togglePlayPauseCommandTarget: Any?
    private var playCommandTarget: Any?
    private var pauseCommandTarget: Any?
    private var changePlaybackPositionCommand: Any?
    private var timeObservers: [TextureId: Any] = [:]

    init() {
        // setup remote commands
        setupRemoteCommands()
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        togglePlayPauseCommandTarget = commandCenter.togglePlayPauseCommand.addTarget {
            [weak self] _ in
            guard let player = self?.remotePlayer else {
                return .noActionableNowPlayingItem
            }
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
            return .success
        }
        playCommandTarget = commandCenter.playCommand.addTarget { [weak self] _ in
            guard let player = self?.remotePlayer else {
                return .noActionableNowPlayingItem
            }
            player.play()
            return .success
        }
        pauseCommandTarget = commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let player = self?.remotePlayer else {
                return .noActionableNowPlayingItem
            }
            player.pause()
            return .success
        }
        changePlaybackPositionCommand = commandCenter.changePlaybackPositionCommand.addTarget {
            [weak self] event in
            guard let player = self?.remotePlayer,
                    let positionCommandEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let millis = TimeUtils.FLTNSTimeIntervalToMillis(positionCommandEvent.positionTime)
            player.seekTo(millis: Int64(millis))
            return .success
        }
    }

    func setupRemoteNotification(
        textureId: TextureId,
        player: VideoPlayer,
        title: String?,
        author: String?,
        imageUrl: String?
    ) {
        remotePlayer = player
        beginReceivingRemoteControlEvents()
        setupRemoteCommandNotification(
            textureId: textureId,
            title: title,
            author: author,
            imageUrl: imageUrl
        )
        addPeriodicTimeObserver(
            textureId: textureId,
            title: title,
            author: author,
            imageUrl: imageUrl
        )
    }

    private func beginReceivingRemoteControlEvents() {
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func endReceivingRemoteControlEvents() {
        try? AVAudioSession.sharedInstance().setActive(false)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    private func setupRemoteCommandNotification(
        textureId: Int, title: String?, author: String?, imageUrl: String?
    ) {
        guard let player = remotePlayer, let duration = player.duration else {
            return
        }
        let positionInSeconds = CMTimeGetSeconds(player.currentTime)
        let durationInSeconds = CMTimeGetSeconds(duration)

        var nowPlayingInfoDict: [String: Any] = [
            MPMediaItemPropertyArtist: author ?? "",
            MPMediaItemPropertyTitle: title ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: positionInSeconds,
            MPMediaItemPropertyPlaybackDuration: durationInSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: 1,
        ]
//        artworkManager.fetchArtwork(textureId: textureId, player: player, imageUrl: imageUrl) {
//            artwork in
//            nowPlayingInfoDict[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
//        }
    }

    private func addPeriodicTimeObserver(
        textureId: Int,
        title: String?,
        author: String?,
        imageUrl: String?
    ) {
        guard let player = remotePlayer else { return }
        let timeObserver = player.player.addPeriodicTimeObserver(
            forInterval: CMTimeMake(value: 1, timescale: 1),
            queue: .global()
        ) { [weak self] _ in
            self?.setupRemoteCommandNotification(
                textureId: textureId, title: title, author: author, imageUrl: imageUrl)
        }
        timeObservers[textureId] = timeObserver
    }

    private func removePeriodicTimeObserver(textureId: Int, player: VideoPlayer) {
        if let timeObserver = timeObservers[textureId] {
            player.player.removeTimeObserver(timeObserver)
        }
        timeObservers.removeValue(forKey: textureId)
    }

    func disposePlayer(textureId: TextureId, player: VideoPlayer) {
        remotePlayer = nil
        endReceivingRemoteControlEvents()
        removePeriodicTimeObserver(textureId: textureId, player: player)
//        artworkManager.removeCache(textureId: textureId)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
