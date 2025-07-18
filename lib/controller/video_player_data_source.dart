import 'dart:io';

import 'package:video_player/configurations/configurations.dart';
import 'package:video_player/subtitles/subtitles.dart';

class VideoPlayerDataSource {
  VideoPlayerDataSource({
    required this.sourceType,
    this.fileUrl,
    this.drmDashFileUrl,
    this.drmHlsFileUrl,
    this.offlineKey,
    this.startPosition,
    this.subtitles,
    this.headers,
    this.bufferingConfiguration = const VideoPlayerBufferingConfiguration(),
    this.notificationConfiguration,
    this.disableRemoteControl = false,
  });

  /// Describes the type of data source this [VideoPlayerController]
  /// is constructed with.
  ///
  /// The way in which the video was originally loaded.
  ///
  /// This has nothing to do with the video's file type. It's just the place
  /// from which the video is fetched from.
  final VideoPlayerDataSourceType sourceType;

  /// The URL to the video file. Only set for [DataSourceType.network] videos.
  final String? fileUrl;

  /// The URL to the Dash drm file. Only set for [DataSourceType.network] videos.
  final String? drmDashFileUrl;

  /// The URL to the hls drm file. Only set for [DataSourceType.network] videos.
  final String? drmHlsFileUrl;

  /// The key of the downloaded video file. Only set for [DataSourceType.offline] videos.
  final String? offlineKey;

  final Duration? startPosition;

  ///Subtitles configuration
  final List<VideoPlayerSubtitlesSource>? subtitles;

  final Map<String, String?>? headers;

  ///Configuration of video buffering. Currently only supported in Android
  ///platform.
  final VideoPlayerBufferingConfiguration bufferingConfiguration;

  ///Configuration of remote controls notification
  final VideoPlayerNotificationConfiguration? notificationConfiguration;

  final bool disableRemoteControl;

  /// The URL to the FairPlay cert. Only set for [DataSourceType.network] videos.
  String fairplayCertUrl = const String.fromEnvironment('FAIRPLAY_CERT_URL');

  /// The URL to the FairPlay license. Only set for [DataSourceType.network] videos.
  String fairplayLicenseUrl =
      const String.fromEnvironment('FAIRPLAY_LICENSE_URL');

  /// The URL to the Widevine license. Only set for [DataSourceType.network] videos.
  String widevineLicenseUrl =
      const String.fromEnvironment('WIDEVINE_LICENSE_URL');

  bool get isDrm =>
      (Platform.isAndroid && drmDashFileUrl != null) ||
      (Platform.isIOS && drmHlsFileUrl != null);
}

/// The way in which the video was originally loaded.
///
/// This has nothing to do with the video's file type. It's just the place
/// from which the video is fetched from.
enum VideoPlayerDataSourceType {
  /// The video was downloaded from the internet.
  network,

  offline,
}
