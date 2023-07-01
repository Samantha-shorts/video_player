import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/configurations/video_player_buffering_configuration.dart';
import 'package:video_player/platform_event.dart';
import 'package:video_player/utils.dart';
import 'package:video_player/video_player_data_source.dart';

import 'video_player_platform_interface.dart';

/// An implementation of [VideoPlayerPlatform] that uses method channels.
class MethodChannelVideoPlayer extends VideoPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('video_player');

  @override
  Future<void> init() => methodChannel.invokeMethod('init');

  @override
  Future<void> dispose(int? textureId) => methodChannel.invokeMethod(
        'dispose',
        <String, dynamic>{'textureId': textureId},
      );

  @override
  Future<int?> create(
      VideoPlayerBufferingConfiguration bufferingConfiguration) async {
    final response = await methodChannel.invokeMethod(
      'create',
      <String, dynamic>{
        'minBufferMs': bufferingConfiguration.minBufferMs,
        'maxBufferMs': bufferingConfiguration.maxBufferMs,
        'bufferForPlaybackMs': bufferingConfiguration.bufferForPlaybackMs,
        'bufferForPlaybackAfterRebufferMs':
            bufferingConfiguration.bufferForPlaybackAfterRebufferMs,
      },
    );
    final map = Map<String, dynamic>.from(response);
    return map["textureId"] as int?;
  }

  EventChannel _eventChannelFor(int? textureId) =>
      EventChannel('video_player_channel/videoEvents$textureId');

  @override
  Stream<PlatformEvent> eventStreamFor(int? textureId) {
    return _eventChannelFor(textureId)
        .receiveBroadcastStream()
        .map((dynamic event) {
      late Map<dynamic, dynamic> map;
      if (event is Map) {
        map = event;
      }
      final eventType = platformEventTypeFromString(map["event"] as String);
      switch (eventType) {
        case PlatformEventType.initialized:
          double width = 0;
          double height = 0;

          try {
            if (map.containsKey("width")) {
              final num widthNum = map["width"] as num;
              width = widthNum.toDouble();
            }
            if (map.containsKey("height")) {
              final num heightNum = map["height"] as num;
              height = heightNum.toDouble();
            }
          } catch (exception) {
            Utils.log(exception.toString());
          }

          final Size size = Size(width, height);

          return PlatformEvent(
            eventType: eventType,
            // key: key,
            duration: Duration(milliseconds: map['duration'] as int),
            size: size,
          );
        case PlatformEventType.isPlayingChanged:
          return PlatformEvent(
            eventType: eventType,
            isPlaying: map["isPlaying"] as bool,
          );
        case PlatformEventType.positionChanged:
          return PlatformEvent(
            eventType: eventType,
            position: Duration(milliseconds: map["position"] as int),
          );
        case PlatformEventType.bufferChanged:
          final values = map['bufferRange'] as List;
          return PlatformEvent(
            eventType: eventType,
            buffered: DurationRange(
              Duration(milliseconds: values[0]),
              Duration(milliseconds: values[1]),
            ),
          );
        case PlatformEventType.pipChanged:
          final isPip = map['isPip'] as bool;
          return PlatformEvent(
            eventType: eventType,
            isPip: isPip,
          );
        case PlatformEventType.muteChanged:
          final isMuted = map['isMuted'] as bool;
          return PlatformEvent(
            eventType: eventType,
            isMuted: isMuted,
          );
        case PlatformEventType.error:
          final errorDescription = map['error'] as String;
          throw errorDescription;
        case PlatformEventType.unknown:
          throw "Unknown event type";
      }
    });
  }

  @override
  Widget buildView(int? textureId, bool isFullscreen) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'matsune/video_player',
        creationParamsCodec: const StandardMessageCodec(),
        creationParams: {'textureId': textureId!, 'isFullscreen': isFullscreen},
      );
    } else {
      return Texture(textureId: textureId!);
    }
  }

  @override
  Future<void> setDataSource(
      int? textureId, VideoPlayerDataSource dataSource) async {
    Map<String, dynamic>? dataSourceDescription;
    switch (dataSource.sourceType) {
      case DataSourceType.network:
        dataSourceDescription = <String, dynamic>{
          'uri': dataSource.uri,
          // 'formatHint': dataSource.rawFormalHint,
          'headers': dataSource.headers,
          // 'useCache': dataSource.useCache,
          // 'maxCacheSize': dataSource.maxCacheSize,
          // 'maxCacheFileSize': dataSource.maxCacheFileSize,
          // 'cacheKey': dataSource.cacheKey,
          // 'showNotification': dataSource.showNotification,
          // 'title': dataSource.title,
          // 'author': dataSource.author,
          // 'imageUrl': dataSource.imageUrl,
          // 'notificationChannelName': dataSource.notificationChannelName,
          // 'overriddenDuration': dataSource.overriddenDuration?.inMilliseconds,
          // 'licenseUrl': dataSource.licenseUrl,
          // 'certificateUrl': dataSource.certificateUrl,
          // 'drmHeaders': dataSource.drmHeaders,
          // 'activityName': dataSource.activityName,
          // 'clearKey': dataSource.clearKey,
          // 'videoExtension': dataSource.videoExtension,
        };
        break;
    }
    await methodChannel.invokeMethod<void>(
      'setDataSource',
      <String, dynamic>{
        'textureId': textureId,
        'dataSource': dataSourceDescription,
      },
    );
    return;
  }

  @override
  Future<void> play(int? textureId) => methodChannel.invokeMethod(
        'play',
        <String, dynamic>{'textureId': textureId},
      );

  @override
  Future<void> pause(int? textureId) => methodChannel.invokeMethod(
        'pause',
        <String, dynamic>{'textureId': textureId},
      );

  @override
  Future<void> seekTo(int? textureId, Duration position) {
    return methodChannel.invokeMethod<void>(
      'seekTo',
      <String, dynamic>{
        'textureId': textureId,
        'position': position.inMilliseconds,
      },
    );
  }

  @override
  Future<void> willExitFullscreen(int? textureId) {
    return methodChannel.invokeMethod<void>(
      'willExitFullscreen',
      <String, dynamic>{
        'textureId': textureId,
      },
    );
  }

  @override
  Future<bool> isPictureInPictureSupported() async {
    final response =
        await methodChannel.invokeMethod('isPictureInPictureSupported');
    final map = Map<String, dynamic>.from(response);
    return map["isPictureInPictureSupported"] as bool;
  }

  @override
  Future<void> enablePictureInPicture(int? textureId) {
    return methodChannel.invokeMethod<void>(
      'enablePictureInPicture',
      <String, dynamic>{
        'textureId': textureId,
      },
    );
  }

  @override
  Future<void> disablePictureInPicture(int? textureId) {
    return methodChannel.invokeMethod<void>(
      'disablePictureInPicture',
      <String, dynamic>{
        'textureId': textureId,
      },
    );
  }

  @override
  Future<void> setMuted(int? textureId, bool muted) {
    return methodChannel.invokeMethod<void>(
      'setMuted',
      <String, dynamic>{
        'textureId': textureId,
        'muted': muted,
      },
    );
  }

  @override
  Future<void> setPlaybackRate(int? textureId, double rate) {
    return methodChannel.invokeMethod<void>(
      'setPlaybackRate',
      <String, dynamic>{
        'textureId': textureId,
        'rate': rate,
      },
    );
  }

  @override
  Future<void> setTrackParameters(
      int? textureId, int? width, int? height, int? bitrate) {
    return methodChannel.invokeMethod<void>(
      'setTrackParameters',
      <String, dynamic>{
        'textureId': textureId,
        'width': width,
        'height': height,
        'bitrate': bitrate,
      },
    );
  }
}
