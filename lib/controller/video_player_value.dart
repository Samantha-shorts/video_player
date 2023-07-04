import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/platform/platform.dart';

// reason why value of VideoPlayerController has changed
enum VideoPlayerEventType {
  initialized,
  isPlayingChanged,
  positionChanged,
  bufferChanged,
  pipChanged,
  muteChanged,
  fullscreenChanged,
  error,
}

class VideoPlayerValue {
  /// Constructs a video with the given values. Only [duration] is required. The
  /// rest will initialize with default values when unset.
  VideoPlayerValue({
    this.eventType,
    this.duration,
    this.size,
    this.buffered,
    this.isPlaying = false,
    this.playbackRate = 1.0,
    this.position = Duration.zero,
    this.isMuted = false,
    this.isFullscreen = false,
    this.isPip = false,
    this.errorDescription,
  });

  VideoPlayerEventType? eventType;

  /// The total duration of the video.
  ///
  /// Is null when [initialized] is false.
  final Duration? duration;

  /// The [size] of the currently loaded video.
  ///
  /// Is null when [initialized] is false.
  final Size? size;

  final DurationRange? buffered;

  bool isPlaying;

  final double playbackRate;

  final Duration position;

  final bool isMuted;

  final bool isFullscreen;

  final bool isPip;

  /// A description of the error if present.
  ///
  /// If [hasError] is false this is [null].
  final String? errorDescription;

  bool get initialized => duration != null;

  /// Returns a new instance that has the same values as this current instance,
  /// except for any overrides passed in as arguments to [copyWidth].
  VideoPlayerValue copyWith({
    VideoPlayerEventType? eventType,
    Duration? duration,
    Size? size,
    DurationRange? buffered,
    bool? isPlaying,
    double? playbackRate,
    Duration? position,
    bool? isMuted,
    bool? isFullscreen,
    bool? isPip,
    String? errorDescription,
  }) {
    return VideoPlayerValue(
      eventType: eventType ?? this.eventType,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackRate: playbackRate ?? this.playbackRate,
      position: position ?? this.position,
      isMuted: isMuted ?? this.isMuted,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      isPip: isPip ?? this.isPip,
      errorDescription: errorDescription ?? this.errorDescription,
    );
  }

  @override
  String toString() {
    // ignore: no_runtimetype_tostring
    return '$runtimeType('
        'eventType: $eventType, '
        'duration: $duration, '
        'size: $size, '
        'isPlaying: $isPlaying, '
        'playbackRate: $playbackRate, '
        'position: $position, '
        'isMuted: $isMuted, '
        'isFullscreen: $isFullscreen, '
        'isPip: $isPip, '
        'buffered: ${buffered ?? '[]'}, '
        'errorDescription: $errorDescription)';
  }
}
