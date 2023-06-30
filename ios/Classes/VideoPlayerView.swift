//
//  VideoPlayerView.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/06/25.
//

import AVKit
import UIKit

class VideoPlayerView: UIView {
  override class var layerClass: AnyClass {
    AVPlayerLayer.self
  }

  var playerLayer: AVPlayerLayer {
    layer as! AVPlayerLayer
  }

  var player: AVPlayer? {
    get {
      playerLayer.player
    }
    set {
      playerLayer.player = newValue
    }
  }
}
