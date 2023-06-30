
import 'video_player_platform_interface.dart';

class VideoPlayer {
  Future<String?> getPlatformVersion() {
    return VideoPlayerPlatform.instance.getPlatformVersion();
  }
}
