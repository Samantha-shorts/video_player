import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'video_player_platform_interface.dart';

/// An implementation of [VideoPlayerPlatform] that uses method channels.
class MethodChannelVideoPlayer extends VideoPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('video_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
