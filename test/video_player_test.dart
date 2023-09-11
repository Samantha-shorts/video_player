import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player/platform/platform_event.dart';
import 'package:video_player/platform/video_player_platform_interface.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayerPlatform
    with MockPlatformInterfaceMixin
    implements VideoPlayerPlatform {
  @override
  Widget buildView(int? textureId, bool isFullscreen) {
    // TODO: implement buildView
    throw UnimplementedError();
  }

  @override
  Future<void> cancelDownload(String key) {
    // TODO: implement cancelDownload
    throw UnimplementedError();
  }

  @override
  Future<int?> create(
      VideoPlayerBufferingConfiguration bufferingConfiguration) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  Future<void> deleteOfflineAsset(String key) {
    // TODO: implement deleteOfflineAsset
    throw UnimplementedError();
  }

  @override
  Future<void> disablePictureInPicture(int? textureId) {
    // TODO: implement disablePictureInPicture
    throw UnimplementedError();
  }

  @override
  Future<void> dispose(int? textureId) {
    // TODO: implement dispose
    throw UnimplementedError();
  }

  @override
  Stream<PlatformDownloadEvent> downloadEventStream() {
    // TODO: implement downloadEventStream
    throw UnimplementedError();
  }

  @override
  Future<void> downloadOfflineAsset(
      {required String key,
      required String url,
      Map<String, String?>? headers}) {
    // TODO: implement downloadOfflineAsset
    throw UnimplementedError();
  }

  @override
  Future<void> enablePictureInPicture(int? textureId) {
    // TODO: implement enablePictureInPicture
    throw UnimplementedError();
  }

  @override
  Stream<PlatformEvent> eventStreamFor(int? textureId) {
    // TODO: implement eventStreamFor
    throw UnimplementedError();
  }

  @override
  Future<List<Download>> getDownloads() {
    // TODO: implement getDownloads
    throw UnimplementedError();
  }

  @override
  Future<void> init() {
    // TODO: implement init
    throw UnimplementedError();
  }

  @override
  Future<bool> isPictureInPictureSupported() {
    // TODO: implement isPictureInPictureSupported
    throw UnimplementedError();
  }

  @override
  Future<void> pause(int? textureId) {
    // TODO: implement pause
    throw UnimplementedError();
  }

  @override
  Future<void> pauseDownload(String key) {
    // TODO: implement pauseDownload
    throw UnimplementedError();
  }

  @override
  Future<void> play(int? textureId) {
    // TODO: implement play
    throw UnimplementedError();
  }

  @override
  Future<void> resumeDownload(String key) {
    // TODO: implement resumeDownload
    throw UnimplementedError();
  }

  @override
  Future<void> seekTo(int? textureId, Duration position) {
    // TODO: implement seekTo
    throw UnimplementedError();
  }

  @override
  Future<void> selectLegibleMediaGroup(int? textureId, int? index) {
    // TODO: implement selectLegibleMediaGroup
    throw UnimplementedError();
  }

  @override
  Future<void> setDataSource(int? textureId, VideoPlayerDataSource dataSource) {
    // TODO: implement setDataSource
    throw UnimplementedError();
  }

  @override
  Future<void> setMuted(int? textureId, bool muted) {
    // TODO: implement setMuted
    throw UnimplementedError();
  }

  @override
  Future<void> setPlaybackRate(int? textureId, double rate) {
    // TODO: implement setPlaybackRate
    throw UnimplementedError();
  }

  @override
  Future<void> setTrackParameters(
      int? textureId, int? width, int? height, int? bitrate) {
    // TODO: implement setTrackParameters
    throw UnimplementedError();
  }

  @override
  Future<void> willExitFullscreen(int? textureId) {
    // TODO: implement willExitFullscreen
    throw UnimplementedError();
  }
}

void main() {
  // final VideoPlayerPlatform initialPlatform = VideoPlayerPlatform.instance;

  // test('$MethodChannelVideoPlayer is the default instance', () {
  //   expect(initialPlatform, isInstanceOf<MethodChannelVideoPlayer>());
  // });

  // test('getPlatformVersion', () async {
  //   VideoPlayer videoPlayerPlugin = VideoPlayer();
  //   MockVideoPlayerPlatform fakePlatform = MockVideoPlayerPlatform();
  //   VideoPlayerPlatform.instance = fakePlatform;

  //   expect(await videoPlayerPlugin.getPlatformVersion(), '42');
  // });
}
