import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/abr/abr_utils.dart';
import 'package:video_player/configurations/video_player_buffering_configuration.dart';
import 'package:video_player/configurations/video_player_configuration.dart';
import 'package:video_player/configurations/video_player_notification_configuration.dart';
import 'package:video_player/platform_event.dart';
import 'package:video_player/subtitles/video_player_subtitles_controller.dart';
import 'package:video_player/utils.dart';
import 'package:video_player/video_player_data_source.dart';
import 'package:video_player/video_player_platform_interface.dart';
import 'package:video_player/video_player_tracks_controller.dart';
import 'package:video_player/video_player_value.dart';

class VideoPlayerControllerProvider extends InheritedWidget {
  const VideoPlayerControllerProvider({
    Key? key,
    required this.controller,
    required Widget child,
  }) : super(key: key, child: child);

  final VideoPlayerController controller;

  @override
  bool updateShouldNotify(VideoPlayerControllerProvider oldWidget) =>
      controller != oldWidget.controller;
}

class VideoPlayerController extends ValueNotifier<VideoPlayerValue> {
  VideoPlayerController({
    required this.configuration,
    VideoPlayerDataSource? dataSource,
  }) : super(VideoPlayerValue()) {
    _create();
    if (dataSource != null) _setDataSource(dataSource);
  }

  final VideoPlayerConfiguration configuration;
  VideoPlayerBufferingConfiguration bufferingConfiguration =
      const VideoPlayerBufferingConfiguration();

  int? _textureId;

  int? get textureId => _textureId;

  StreamSubscription<PlatformEvent>? _eventSubscription;

  bool _isDisposed = false;

  late Completer<void> _initializeCompleter;

  final Completer<void> _createCompleter = Completer<void>();

  final VideoPlayerSubtitlesController subtitlesController =
      VideoPlayerSubtitlesController();

  final VideoPlayerTracksController tracksController =
      VideoPlayerTracksController();

  final StreamController<bool> controlsVisibilityStreamController =
      StreamController.broadcast();

  Stream<bool> get controlsVisibilityStream =>
      controlsVisibilityStreamController.stream;

  static VideoPlayerController of(BuildContext context) {
    final videoPLayerControllerProvider = context
        .dependOnInheritedWidgetOfExactType<VideoPlayerControllerProvider>()!;
    return videoPLayerControllerProvider.controller;
  }

  Future<void> _create() async {
    _textureId =
        await VideoPlayerPlatform.instance.create(bufferingConfiguration);
    tracksController.textureId = _textureId;
    _createCompleter.complete(null);

    void eventListener(PlatformEvent event) {
      if (_isDisposed) {
        return;
      }
      switch (event.eventType) {
        case PlatformEventType.initialized:
          value = value.copyWith(
            eventType: VideoPlayerEventType.initialized,
            duration: event.duration,
            size: event.size,
          );
          _initializeCompleter.complete(null);
          break;
        case PlatformEventType.isPlayingChanged:
          value = value.copyWith(
            eventType: VideoPlayerEventType.isPlayingChanged,
            isPlaying: event.isPlaying,
          );
          break;
        case PlatformEventType.positionChanged:
          value = value.copyWith(
            eventType: VideoPlayerEventType.positionChanged,
            position: event.position,
          );
          break;
        case PlatformEventType.bufferChanged:
          value = value.copyWith(
            eventType: VideoPlayerEventType.bufferChanged,
            buffered: event.buffered,
          );
          break;
        case PlatformEventType.pipChanged:
          value = value.copyWith(
            eventType: VideoPlayerEventType.pipChanged,
            isPip: event.isPip,
          );
          break;
        case PlatformEventType.muteChanged:
          value = value.copyWith(
            eventType: VideoPlayerEventType.muteChanged,
            isMuted: event.isMuted,
          );
          break;
        default:
          break;
      }
    }

    void errorListener(Object object) {
      if (object is PlatformException) {
        final PlatformException e = object;
        value = value.copyWith(
          eventType: VideoPlayerEventType.error,
          errorDescription: e.message,
        );
      } else {
        value = value.copyWith(
          eventType: VideoPlayerEventType.error,
          errorDescription: object.toString(),
        );
      }
      if (!_initializeCompleter.isCompleted) {
        _initializeCompleter.completeError(object);
      }
    }

    _eventSubscription = VideoPlayerPlatform.instance
        .eventStreamFor(textureId)
        .listen(eventListener, onError: errorListener);
  }

  @override
  void dispose() async {
    await _createCompleter.future;
    if (!_isDisposed) {
      _isDisposed = true;
      await _eventSubscription?.cancel();
      await VideoPlayerPlatform.instance.dispose(textureId);
    }
    super.dispose();
  }

  /// Set data source for playing a video from obtained from
  /// the network.
  Future<void> setNetworkDataSource(
    String uri, {
    Map<String, String?>? headers,
    VideoPlayerNotificationConfiguration? notificationConfiguration,
  }) {
    return _setDataSource(
      VideoPlayerDataSource(
        sourceType: DataSourceType.network,
        uri: uri,
        headers: headers,
        notificationConfiguration: notificationConfiguration,
      ),
    );
  }

  Future<void> _setDataSource(VideoPlayerDataSource dataSource) async {
    if (_isDisposed) {
      return;
    }
    bufferingConfiguration = dataSource.bufferingConfiguration;
    value = VideoPlayerValue();
    if (!_createCompleter.isCompleted) await _createCompleter.future;
    _initializeCompleter = Completer<void>();

    await VideoPlayerPlatform.instance.setDataSource(textureId, dataSource);

    tracksController.reset();
    subtitlesController.reset();

    if (Utils.isDataSourceHls(dataSource.uri)) {
      _loadAbrManifest(dataSource);
    }

    return _initializeCompleter.future;
  }

  Future<void> _loadAbrManifest(VideoPlayerDataSource dataSource) async {
    final data = await Utils.getDataFromUrl(
      dataSource.uri!,
      dataSource.headers,
    );
    if (data == null) return;

    final abrData = await AbrUtils.parse(data, dataSource.uri!);

    tracksController.setTracksList(abrData.tracks ?? []);
    subtitlesController.setSubtitlesSourceList(abrData.subtitles ?? []);
    subtitlesController.selectDefaultSource();

    if (subtitlesController.isSelectedNone) return;

    if (subtitlesController.selectedSubtitlesSource?.asmsIsSegmented == true) {
      return;
    }
    subtitlesController.loadAllSubtitleLines();
  }

  Future<void> play() async {
    if (!value.initialized || _isDisposed || value.isPlaying) return;
    await VideoPlayerPlatform.instance.play(textureId);
  }

  Future<void> pause() async {
    if (!value.initialized || _isDisposed || !value.isPlaying) return;
    await VideoPlayerPlatform.instance.pause(textureId);
  }

  Future<void> seekTo(Duration? position) async {
    if (!value.initialized || _isDisposed || position == null) {
      return;
    }
    Duration? positionToSeek = position;
    if (position > value.duration!) {
      positionToSeek = value.duration;
    } else if (position < const Duration()) {
      positionToSeek = const Duration();
    }

    if (positionToSeek != null) {
      await VideoPlayerPlatform.instance.seekTo(textureId, positionToSeek);
    }
  }

  void enterFullscreen() {
    if (!value.initialized || _isDisposed) return;
    value = value.copyWith(
      eventType: VideoPlayerEventType.fullscreenChanged,
      isFullscreen: true,
    );
  }

  void exitFullscreen() {
    if (!value.initialized || _isDisposed) return;
    VideoPlayerPlatform.instance.willExitFullscreen(_textureId);
    value = value.copyWith(
      eventType: VideoPlayerEventType.fullscreenChanged,
      isFullscreen: false,
    );
  }

  Future<bool> isPictureInPictureSupported() =>
      VideoPlayerPlatform.instance.isPictureInPictureSupported();

  Future<void> enablePictureInPicture() async {
    final bool isPipSupported = await isPictureInPictureSupported();
    if (!isPipSupported) return;
    await VideoPlayerPlatform.instance.enablePictureInPicture(textureId);
    if (Platform.isAndroid) {
      enterFullscreen();
    }
  }

  Future<void> disablePictureInPicture() =>
      VideoPlayerPlatform.instance.disablePictureInPicture(textureId);

  Future<void> setMuted(bool muted) =>
      VideoPlayerPlatform.instance.setMuted(textureId, muted);

  Future<void> setPlaybackRate(double rate) {
    value = value.copyWith(playbackRate: rate);
    return VideoPlayerPlatform.instance.setPlaybackRate(textureId, rate);
  }
}
