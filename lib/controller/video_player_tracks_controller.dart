import 'dart:async';

import 'package:video_player/abr/abr.dart';
import 'package:video_player/platform/platform.dart';

enum VideoPlayerTracksStreamEvent {
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

  void selectTrack(AbrTrack track) {
    VideoPlayerPlatform.instance.setTrackParameters(
      textureId,
      track.width,
      track.height,
      track.bitrate,
    );

    if (_selectedTrack == null || _selectedTrack != track) {
      _selectedTrack = track;
      _videoPlayerTracksStreamController
          .add(VideoPlayerTracksStreamEvent.didUpdate);
    }
  }
}
