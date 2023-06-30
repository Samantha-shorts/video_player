import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player/video_player_platform_interface.dart';
import 'package:video_player/video_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVideoPlayerPlatform
    with MockPlatformInterfaceMixin
    implements VideoPlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VideoPlayerPlatform initialPlatform = VideoPlayerPlatform.instance;

  test('$MethodChannelVideoPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVideoPlayer>());
  });

  test('getPlatformVersion', () async {
    VideoPlayer videoPlayerPlugin = VideoPlayer();
    MockVideoPlayerPlatform fakePlatform = MockVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;

    expect(await videoPlayerPlugin.getPlatformVersion(), '42');
  });
}
