import AVKit
import Flutter
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

public class VideoPlayerPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "video_player", binaryMessenger: registrar.messenger())
    let instance = VideoPlayerPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.register(instance, withId: "com.samansa/video_player")
  }

  private let registrar: FlutterPluginRegistrar
  private let messenger: FlutterBinaryMessenger
  private var players: [Int: VideoPlayer] = [:]
  private var dataSources: [Int: DataSource] = [:]

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
        "isPictureInPictureSupported": AVPictureInPictureController.isPictureInPictureSupported()
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
        player.setDataSource(url: uri)

        result(nil)
      case .play:
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
  func createVideoPlayer() -> Int {
    let textureId = nextTextureId
    let eventChannel = FlutterEventChannel(
      name: "video_player_channel/videoEvents\(textureId)",
      binaryMessenger: messenger
    )
    players[textureId] = VideoPlayer(eventChannel: eventChannel)
    return textureId
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
