import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/platform/platform.dart';

// reason why value of VideoPlayerController has changed
enum VideoPlayerEventType {
  initialized,
  isPlayingChanged,
  onPlaybackStateChanged,
  positionChanged,
  bufferChanged,
  pipChanged,
  expandChanged,
  muteChanged,
  fullscreenChanged,
  ended,
  error,
}

class VideoPlayerValue {
  /// Constructs a video with the given values. Only [duration] is required. The
  /// rest will initialize with default values when unset.
  VideoPlayerValue({
    this.eventType,
    this.playbackState = 0,
    this.duration,
    this.size,
    this.buffered,
    this.isPlaying = false,
    this.playbackRate = 1.0,
    this.position = Duration.zero,
    this.isMuted = false,
    this.isFullscreen = false,
    this.isPip = false,
    this.isExpanded = false,
    this.errorDescription,
    this.errorDetails,
    this.invalid,
    this.errorCode,
    int? stateChangedTimestamp,
  }) : playbackStateChangedTimestamp =
            stateChangedTimestamp ?? DateTime.now().millisecondsSinceEpoch;

  VideoPlayerEventType? eventType;

  /// Only use Android platform.
  /// https://developer.android.com/media/media3/exoplayer/listening-to-player-events?utm_source=chatgpt.com&hl=ja#playback-state
  final int playbackState;

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

  final bool isExpanded;

  /// A description of the error if present.
  ///
  /// If [hasError] is false this is [null].
  final String? errorDescription;

  final String? errorDetails;

  final bool? invalid;

  final int? errorCode;

  bool get initialized => duration != null;

  bool get isFinished => position.inSeconds == duration?.inSeconds;

  /// Only use Android platform.
  int playbackStateChangedTimestamp;

  /// Returns a new instance that has the same values as this current instance,
  /// except for any overrides passed in as arguments to [copyWidth].
  VideoPlayerValue copyWith({
    VideoPlayerEventType? eventType,
    int? playbackState,
    Duration? duration,
    Size? size,
    DurationRange? buffered,
    bool? isPlaying,
    double? playbackRate,
    Duration? position,
    bool? isMuted,
    bool? isFullscreen,
    bool? isPip,
    bool? isExpanded,
    String? errorDescription,
    String? errorDetails,
    bool? invalid,
    int? errorCode,
  }) {
    int? playbackStateChangedTimestamp;
    if (playbackState != this.playbackState && playbackState == 3) {
      playbackStateChangedTimestamp = DateTime.now().millisecondsSinceEpoch;
    }
    return VideoPlayerValue(
      eventType: eventType ?? this.eventType,
      playbackState: playbackState ?? this.playbackState,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackRate: playbackRate ?? this.playbackRate,
      position: position ?? this.position,
      isMuted: isMuted ?? this.isMuted,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      isPip: isPip ?? this.isPip,
      isExpanded: isExpanded ?? this.isExpanded,
      errorDescription: errorDescription ?? this.errorDescription,
      errorDetails: errorDetails ?? this.errorDetails,
      invalid: invalid ?? this.invalid,
      errorCode: errorCode ?? this.errorCode,
      stateChangedTimestamp:
          playbackStateChangedTimestamp ?? this.playbackStateChangedTimestamp,
    );
  }

  @override
  String toString() {
    // ignore: no_runtimetype_tostring
    return '$runtimeType('
        'eventType: $eventType, '
        'playbackState: $playbackState, '
        'duration: $duration, '
        'size: $size, '
        'isPlaying: $isPlaying, '
        'playbackRate: $playbackRate, '
        'position: $position, '
        'isMuted: $isMuted, '
        'isFullscreen: $isFullscreen, '
        'isPip: $isPip, '
        'isExpanded: $isExpanded, '
        'buffered: ${buffered ?? '[]'}, '
        'errorDescription: $errorDescription, '
        'errorDetails: $errorDetails), '
        'invalid: $invalid), '
        'errorCode: $errorCode), '
        'stateChangedTimestamp: $playbackStateChangedTimestamp';
  }
}
