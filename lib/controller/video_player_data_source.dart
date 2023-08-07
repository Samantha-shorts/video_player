import 'package:video_player/configurations/configurations.dart';
import 'package:video_player/subtitles/subtitles.dart';

class VideoPlayerDataSource {
  VideoPlayerDataSource({
    required this.sourceType,
    this.url,
    this.offlineKey,
    this.startPosition,
    this.subtitles,
    this.headers,
    this.bufferingConfiguration = const VideoPlayerBufferingConfiguration(),
    this.notificationConfiguration,
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
  final String? url;

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
