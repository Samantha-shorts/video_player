import 'package:flutter/services.dart';
import 'package:video_player/abr/abr.dart';
import 'package:video_player/configurations/configurations.dart';

class VideoPlayerConfiguration {
  /// Play the video as soon as it's displayed
  final bool autoPlay;

  /// Enter fullscreen as soon as it's displayed
  final bool autoFullscreen;

  final bool autoLoop;

  /// The Aspect Ratio of the Video. Important to get the correct size of the
  /// video!
  ///
  /// Will fallback to fitting within the space allowed.
  final double? aspectRatio;

  /// Defines the set of allowed device orientations on entering fullscreen
  final List<DeviceOrientation> deviceOrientationsOnFullScreen;

  /// Defines the system overlays visible after exiting fullscreen
  final List<SystemUiOverlay> systemOverlaysAfterFullScreen;

  /// Defines the set of allowed device orientations after exiting fullscreen
  final List<DeviceOrientation> deviceOrientationsAfterFullScreen;

  ///Defines subtitles configuration
  final VideoPlayerSubtitlesConfiguration subtitlesConfiguration;

  ///Defines controls configuration
  final VideoPlayerControlsConfiguration controlsConfiguration;

  String? Function(AbrTrack track)? quarityTrackSelectable;

  final bool hideControls;

  VideoPlayerConfiguration({
    this.aspectRatio,
    this.autoPlay = false,
    this.autoFullscreen = false,
    this.autoLoop = false,
    this.deviceOrientationsOnFullScreen = const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    this.systemOverlaysAfterFullScreen = SystemUiOverlay.values,
    this.deviceOrientationsAfterFullScreen = const [
      DeviceOrientation.portraitUp,
    ],
    this.subtitlesConfiguration = const VideoPlayerSubtitlesConfiguration(),
    this.controlsConfiguration = const VideoPlayerControlsConfiguration(),
    this.quarityTrackSelectable,
    this.hideControls = false,
  });

  VideoPlayerConfiguration copyWith({
    bool? autoPlay,
    bool? autoFullscreen,
    bool? autoLoop,
    double? aspectRatio,
    List<DeviceOrientation>? deviceOrientationsOnFullScreen,
    List<SystemUiOverlay>? systemOverlaysAfterFullScreen,
    List<DeviceOrientation>? deviceOrientationsAfterFullScreen,
    VideoPlayerSubtitlesConfiguration? subtitlesConfiguration,
    VideoPlayerControlsConfiguration? controlsConfiguration,
    bool? hidesControls,
  }) {
    return VideoPlayerConfiguration(
      autoPlay: autoPlay ?? this.autoPlay,
      autoFullscreen: autoFullscreen ?? this.autoFullscreen,
      autoLoop: autoLoop ?? this.autoLoop,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      deviceOrientationsOnFullScreen:
          deviceOrientationsOnFullScreen ?? this.deviceOrientationsOnFullScreen,
      systemOverlaysAfterFullScreen:
          systemOverlaysAfterFullScreen ?? this.systemOverlaysAfterFullScreen,
      deviceOrientationsAfterFullScreen: deviceOrientationsAfterFullScreen ??
          this.deviceOrientationsAfterFullScreen,
      subtitlesConfiguration:
          subtitlesConfiguration ?? this.subtitlesConfiguration,
      controlsConfiguration:
          controlsConfiguration ?? this.controlsConfiguration,
      hideControls: hidesControls ?? this.hideControls,
    );
  }
}
