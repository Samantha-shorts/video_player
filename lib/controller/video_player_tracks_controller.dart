import 'dart:async';

import 'package:video_player/abr/abr.dart';
import 'package:video_player/platform/platform.dart';

enum VideoPlayerTracksStreamEvent {
  initialize,
  didUpdate,
}

class VideoPlayerTracksController {
  VideoPlayerTracksController();

  int? textureId;

  List<AbrTrack> _abrTracks = [];

  ///List of tracks available for current data source. Used only for HLS / DASH.
  List<AbrTrack> get abrTracks => _abrTracks;

  AbrTrack? _selectedTrack;

  AbrTrack? get selectedTrack => _selectedTrack;

  final _videoPlayerTracksStreamController =
      StreamController<VideoPlayerTracksStreamEvent>.broadcast();

  Stream<VideoPlayerTracksStreamEvent> get videoPlayerTracksStream =>
      _videoPlayerTracksStreamController.stream;

  void reset() {
    _abrTracks = [];
    _selectedTrack = null;
  }

  void setTracksList(List<AbrTrack> tracks) {
    _abrTracks = tracks;
  }

  void selectTrack(
    AbrTrack track, {
    bool initialize = false,
  }) {
    VideoPlayerPlatform.instance.setTrackParameters(
      textureId,
      track.width,
      track.height,
      track.bitrate,
    );

    if (_selectedTrack == null || _selectedTrack != track) {
      _selectedTrack = track;
      _videoPlayerTracksStreamController.add(
        initialize
            ? VideoPlayerTracksStreamEvent.initialize
            : VideoPlayerTracksStreamEvent.didUpdate,
      );
    }
  }

  void setSelectedTrackFromPlatform({
    int? width,
    int? height,
    int? bitrate,
  }) {
    AbrTrack? matchedTrack;
    for (final track in _abrTracks) {
      final matchesWidth = width == null || width <= 0 || track.width == width;
      final matchesHeight = height == null || height <= 0 || track.height == height;
      final matchesBitrate =
          bitrate == null || bitrate <= 0 || track.bitrate == bitrate;
      if (matchesWidth && matchesHeight && matchesBitrate) {
        matchedTrack = track;
        break;
      }
    }

    if (matchedTrack == null && bitrate != null && bitrate > 0) {
      for (final track in _abrTracks) {
        if (track.bitrate == bitrate) {
          matchedTrack = track;
          break;
        }
      }
    }

    if (matchedTrack == null) {
      return;
    }

    if (_selectedTrack == matchedTrack) {
      return;
    }

    _selectedTrack = matchedTrack;
    _videoPlayerTracksStreamController.add(
      VideoPlayerTracksStreamEvent.didUpdate,
    );
  }
}
