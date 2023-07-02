import 'package:video_player/configurations/video_player_buffering_configuration.dart';
import 'package:video_player/configurations/video_player_notification_configuration.dart';

class VideoPlayerDataSource {
  VideoPlayerDataSource({
    required this.sourceType,
    this.uri,
    this.asset,
    this.headers,
    this.bufferingConfiguration = const VideoPlayerBufferingConfiguration(),
    this.notificationConfiguration,
  }) : assert(uri == null || asset == null);

  /// Describes the type of data source this [VideoPlayerController]
  /// is constructed with.
  ///
  /// The way in which the video was originally loaded.
  ///
  /// This has nothing to do with the video's file type. It's just the place
  /// from which the video is fetched from.
  final DataSourceType sourceType;

  /// The URI to the video file.
  ///
  /// This will be in different formats depending on the [DataSourceType] of
  /// the original video.
  final String? uri;

  /// The name of the asset. Only set for [DataSourceType.asset] videos.
  final String? asset;

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
enum DataSourceType {
  // /// The video was included in the app's asset files.
  // asset,

  /// The video was downloaded from the internet.
  network,

  // /// The video was loaded off of the local filesystem.
  // file
}
