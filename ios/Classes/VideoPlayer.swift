//
//  VideoPlayer.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/06/25.
//

import AVKit
import Flutter

enum PlatformEventType: String {
    case initialized
    case isPlayingChanged
    case positionChanged
    case bufferChanged
    case pipChanged
    case muteChanged
    case error
}

class VideoPlayer: NSObject {

    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    let player: AVPlayer
    let playerView: VideoPlayerView
    let fullscreenPlayerView: VideoPlayerView
    private var activePlayerView: VideoPlayerView!
    let videoOutput = AVPlayerItemVideoOutput()
    private var pipController: AVPictureInPictureController?
    private(set) var isDisposed = false
    private(set) var isInitialized = false

    private var observersAdded = false
    private var presentationSizeObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var loadedTimeRangesObservation: NSKeyValueObservation?
    private var isMutedObservation: NSKeyValueObservation?

    private var timeObserver: Any?

    var isMuted: Bool {
        get {
            player.isMuted
        }
        set {
            player.isMuted = newValue
        }
    }

    var playbackRate: Float = 1.0 {
        didSet {
            if isPlaying {
                player.rate = playbackRate
            }
        }
    }

    var isPlaying: Bool {
        player.rate > 0
    }

    var currentTime: CMTime {
        player.currentItem?.currentTime() ?? .zero
    }

    var duration: CMTime? {
        player.currentItem?.duration
    }

    init(eventChannel: FlutterEventChannel) {
        self.eventChannel = eventChannel
        self.player = AVPlayer()
        self.playerView = VideoPlayerView()
        self.fullscreenPlayerView = VideoPlayerView()
        super.init()
        eventChannel.setStreamHandler(self)
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false
        setPlayerViewActive(playerView)
    }

    func setPlayerViewActive(_ playerView: VideoPlayerView) {
        playerView.player = player
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerView.playerLayer)
            pipController?.delegate = self
            if #available(iOS 14.2, *) {
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
            }
        }
        activePlayerView = playerView
    }

    func play() {
        player.rate = playbackRate
    }

    func pause() {
        player.pause()
    }

    func seekTo(millis: Int64, result: (() -> Void)? = nil) {
        let rate = player.rate
        player.seek(
            to: CMTimeMake(value: millis, timescale: 1000),
            toleranceBefore: .zero, toleranceAfter: .zero
        ) { [weak player] _ in
            player?.rate = rate
            result?()
        }
    }

    func clear() {
        isInitialized = false
        isDisposed = false
        removeObservers()
        if let playerItem = player.currentItem {
            playerItem.asset.cancelLoading()
            playerItem.remove(videoOutput)
        }
    }

    func dispose() {
        clear()
        eventChannel.setStreamHandler(nil)
        isDisposed = true
    }

    func setDataSource(url: URL, headers: [String: String]?) {
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers ?? [:]])
        let item = AVPlayerItem(asset: asset)
        item.add(videoOutput)
        player.replaceCurrentItem(with: item)
        addObservers(to: item)
    }

    func sendEvent(_ eventType: PlatformEventType, _ params: [String: Any] = [:]) {
        var paramsWithEvent = params
        paramsWithEvent["event"] = eventType.rawValue
        eventSink?(paramsWithEvent)
    }

    func addObservers(to item: AVPlayerItem) {
        if !observersAdded {
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTimeMake(value: 1, timescale: 2),
                queue: .main,
                using: { [weak self] time in
                    let millis = TimeUtils.FLTCMTimeToMillis(time)
                    self?.sendEvent(.positionChanged, ["position": millis])
                }
            )
            rateObservation = player.observe(\.rate) { [weak self] player, _ in
                let isPlaying = player.rate > 0
                self?.sendEvent(.isPlayingChanged, ["isPlaying": isPlaying])
            }
            isMutedObservation = player.observe(
                \.isMuted,
                changeHandler: { [weak self] player, _ in
                    self?.sendEvent(.muteChanged, ["isMuted": player.isMuted])
                })
            statusObservation = item.observe(\.status) { [weak self] item, _ in
                switch item.status {
                case .failed:
                    self?.sendEvent(.error, ["error": item.error?.localizedDescription as Any])
                case .readyToPlay:
                    self?.readyToPlay()
                default:
                    break
                }
            }
            presentationSizeObservation = item.observe(\.presentationSize) { [weak self] _, _ in
                self?.readyToPlay()
            }
            loadedTimeRangesObservation = item.observe(\.loadedTimeRanges) { [weak self] item, _ in
                if let timeRangeValue = item.loadedTimeRanges.first?.timeRangeValue {
                    let start = TimeUtils.FLTCMTimeToMillis(timeRangeValue.start)
                    var end = start + TimeUtils.FLTCMTimeToMillis(timeRangeValue.duration)
                    if item.forwardPlaybackEndTime.isValid {
                        let endTime = TimeUtils.FLTCMTimeToMillis(item.forwardPlaybackEndTime)
                        end = min(end, endTime)
                    }
                    self?.sendEvent(.bufferChanged, ["bufferRange": [start, end]])
                }
            }
            observersAdded = true
        }
    }

    func removeObservers() {
        if observersAdded {
            if let timeObserver = timeObserver {
                player.removeTimeObserver(timeObserver)
            }
            rateObservation = nil
            statusObservation = nil
            presentationSizeObservation = nil
            rateObservation = nil
            loadedTimeRangesObservation = nil
            isMutedObservation = nil
        }
    }

    func readyToPlay() {
        guard eventSink != nil,
            !isInitialized,
            player.status == .readyToPlay,
            let item = player.currentItem
        else {
            return
        }
        let size = item.presentationSize
        let width = size.width
        let height = size.height
        let onlyAudio = item.asset.tracks(withMediaType: .video).isEmpty

        // The player has not yet initialized.
        if !onlyAudio && height == 0 && width == 0 {
            return
        }

        // Fix from https://github.com/flutter/flutter/issues/66413
        guard let track = item.tracks.first,
            let assetTrack = track.assetTrack
        else {
            return
        }
        let naturalSize = assetTrack.naturalSize
        let prefTrans = assetTrack.preferredTransform
        let realSize = naturalSize.applying(prefTrans)
        let duration = TimeUtils.FLTCMTimeToMillis(item.asset.duration)

        try? AVAudioSession.sharedInstance().setActive(true)
        try? AVAudioSession.sharedInstance().setCategory(.playback)

        isInitialized = true

        sendEvent(
            .initialized,
            [
                "duration": duration,
                "width": abs(realSize.width) != 0 ? realSize.width : width,
                "height": abs(realSize.height) != 0 ? realSize.height : height,
            ]
        )
    }

    func enablePictureInPicture() {
        pipController?.startPictureInPicture()
    }

    func disablePictureInPicture() {
        pipController?.stopPictureInPicture()
    }

    func setTrackParameters(width: Int, height: Int, bitrate: Double) {
        player.currentItem?.preferredPeakBitRate = bitrate
        if width == 0 && height == 0 {
            player.currentItem?.preferredMaximumResolution = .zero
        } else {
            player.currentItem?.preferredMaximumResolution = CGSize(width: width, height: height)
        }
    }
}

extension VideoPlayer: FlutterPlatformView {
    func view() -> UIView {
        activePlayerView
    }
}

extension VideoPlayer: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

extension VideoPlayer: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        sendEvent(.pipChanged, ["isPip": true])
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        sendEvent(.pipChanged, ["isPip": false])
    }
}
