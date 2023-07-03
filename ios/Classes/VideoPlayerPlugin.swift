import AVKit
import Flutter
import MediaPlayer
import UIKit

typealias DataSource = [String: Any]

enum FlutterMethod: String {
    case `init`
    case create
    case isPictureInPictureSupported
    case setDataSource
    case play
    case pause
    case seekTo
    case dispose
    case willExitFullscreen
    case enablePictureInPicture
    case disablePictureInPicture
    case setMuted
    case setPlaybackRate
    case setTrackParameters
}

typealias TextureId = Int

public class VideoPlayerPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "video_player", binaryMessenger: registrar.messenger())
        let instance = VideoPlayerPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(instance, withId: "matsune/video_player")
    }

    private let registrar: FlutterPluginRegistrar
    private let messenger: FlutterBinaryMessenger
    private var players: [TextureId: VideoPlayer] = [:]
    private var dataSources: [TextureId: DataSource] = [:]

    private let artworkManager = ArtworkManager(thumbnailRefreshSec: 60)
    private var remotePlayer: VideoPlayer?
    private var didSetupRemoteCommands = false
    private var togglePlayPauseCommandTarget: Any?
    private var playCommandTarget: Any?
    private var pauseCommandTarget: Any?
    private var changePlaybackPositionCommand: Any?
    private var timeObservers: [TextureId: Any] = [:]

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        self.messenger = registrar.messenger()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = FlutterMethod(rawValue: call.method)
        switch method {
        case .`init`:
            players.forEach { $0.value.dispose() }
            players.removeAll()
            result(nil)
        case .create:
            let textureId = createVideoPlayer()
            result(["textureId": textureId])
        case .isPictureInPictureSupported:
            result([
                "isPictureInPictureSupported":
                    AVPictureInPictureController.isPictureInPictureSupported()
            ])
        default:
            guard let args = call.arguments as? [String: Any],
                let textureId = args["textureId"] as? Int,
                let player = players[textureId]
            else {
                result(nil)
                return
            }
            switch method {
            case .setDataSource:
                player.clear()

                let dataSource = args["dataSource"] as! DataSource
                dataSources[textureId] = dataSource

                guard let uriString = dataSource["uri"] as? String,
                    let uri = URL(string: uriString)
                else {
                    fatalError()
                }
                player.setDataSource(url: uri, headers: dataSource["headers"] as? [String: String])

                result(nil)
            case .play:
                setupRemoteNotification(textureId: textureId)
                player.play()
                result(nil)
            case .pause:
                player.pause()
                result(nil)
            case .seekTo:
                let position = args["position"] as! Int64
                player.seekTo(millis: position) {
                    result(nil)
                }
            case .dispose:
                endReceivingRemoteControlEvents()
                disposeNotificationData(textureId: textureId)
                players.removeValue(forKey: textureId)
                player.dispose()
                if players.isEmpty {
                    try? AVAudioSession.sharedInstance().setActive(
                        false, options: [.notifyOthersOnDeactivation])
                }
                result(nil)
            case .willExitFullscreen:
                player.setPlayerViewActive(player.playerView)
                result(nil)
            case .enablePictureInPicture:
                player.enablePictureInPicture()
                result(nil)
            case .disablePictureInPicture:
                player.disablePictureInPicture()
                result(nil)
            case .setMuted:
                let isMuted = args["muted"] as! Bool
                player.isMuted = isMuted
                result(nil)
            case .setPlaybackRate:
                let rate = args["rate"] as! Float
                player.playbackRate = rate
                result(nil)
            case .setTrackParameters:
                let width = args["width"] as! Int
                let height = args["height"] as! Int
                let bitrate = args["bitrate"] as! Double
                player.setTrackParameters(width: width, height: height, bitrate: bitrate)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    var nextTextureId: Int {
        players.count + 1
    }

    /// returns: texture id
    func createVideoPlayer() -> TextureId {
        let textureId = nextTextureId
        let eventChannel = FlutterEventChannel(
            name: "video_player_channel/videoEvents\(textureId)",
            binaryMessenger: messenger
        )
        players[textureId] = VideoPlayer(eventChannel: eventChannel)
        return textureId
    }

    func setupRemoteNotification(textureId: Int) {
        guard let player = players[textureId],
            let dataSource = dataSources[textureId]
        else {
            return
        }
        let title = dataSource["title"] as? String
        let author = dataSource["author"] as? String
        let imageUrl = dataSource["imageUrl"] as? String
        remotePlayer = player
        setupRemoteCommands(player: player)
        beginReceivingRemoteControlEvents()
        setupRemoteCommandNotification(
            textureId: textureId,
            title: title,
            author: author,
            imageUrl: imageUrl
        )
        setupUpdateListener(
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
        if players.isEmpty {
            try? AVAudioSession.sharedInstance().setActive(false)
        }
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    private func setupRemoteCommands(player: VideoPlayer) {
        if didSetupRemoteCommands {
            return
        }
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
                let positionCommandEvent = event as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }
            let millis = TimeUtils.FLTNSTimeIntervalToMillis(positionCommandEvent.positionTime)
            player.seekTo(millis: Int64(millis))
            return .success
        }
        didSetupRemoteCommands = true
    }

    private func setupRemoteCommandNotification(
        textureId: Int, title: String?, author: String?, imageUrl: String?
    ) {
        guard let player = players[textureId], let duration = player.duration else {
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

        artworkManager.fetchArtwork(textureId: textureId, player: player, imageUrl: imageUrl) {
            artwork in
            nowPlayingInfoDict[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
        }
    }

    private func setupUpdateListener(
        textureId: Int, title: String?, author: String?, imageUrl: String?
    ) {
        guard let player = players[textureId] else { return }
        let timeObserver = player.player.addPeriodicTimeObserver(
            forInterval: CMTimeMake(value: 1, timescale: 1), queue: .global()
        ) { [weak self] _ in
            self?.setupRemoteCommandNotification(
                textureId: textureId, title: title, author: author, imageUrl: imageUrl)
        }
        timeObservers[textureId] = timeObserver
    }

    private func disposeNotificationData(textureId: Int) {
        guard let player = players[textureId] else {
            return
        }
        if player == remotePlayer {
            remotePlayer = nil
            let commandCenter = MPRemoteCommandCenter.shared()
            commandCenter.togglePlayPauseCommand.removeTarget(togglePlayPauseCommandTarget)
            commandCenter.playCommand.removeTarget(playCommandTarget)
            commandCenter.pauseCommand.removeTarget(pauseCommandTarget)
            commandCenter.changePlaybackPositionCommand.removeTarget(changePlaybackPositionCommand)
            didSetupRemoteCommands = false
        }
        if let timeObserver = timeObservers[textureId] {
            player.player.removeTimeObserver(timeObserver)
        }
        timeObservers.removeValue(forKey: textureId)
        artworkManager.removeCache(textureId: textureId)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

extension VideoPlayerPlugin: FlutterPlatformViewFactory {
    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
        -> FlutterPlatformView
    {
        guard let args = args as? [String: Any],
            let textureId = args["textureId"] as? Int,
            let player = players[textureId]
        else {
            fatalError()
        }
        let isFullscreen = args["isFullscreen"] as? Bool
        if isFullscreen == true {
            player.setPlayerViewActive(player.fullscreenPlayerView)
        } else {
            player.setPlayerViewActive(player.playerView)
        }
        return player
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
