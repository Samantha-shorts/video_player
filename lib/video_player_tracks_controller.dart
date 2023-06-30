import 'package:video_player/abr/abr_track.dart';
import 'package:video_player/video_player_platform_interface.dart';

class VideoPlayerTracksController {
  VideoPlayerTracksController();

  int? textureId;

  List<AbrTrack> _abrTracks = [];

  ///List of tracks available for current data source. Used only for HLS / DASH.
  List<AbrTrack> get abrTracks => _abrTracks;

  AbrTrack? _selectedTrack;

  AbrTrack? get selectedTrack => _selectedTrack;

  void reset() {
    _abrTracks = [];
    _selectedTrack = null;
  }

  void setTracksList(List<AbrTrack> tracks) {
    _abrTracks = tracks;
  }

  void selectTrack(AbrTrack track) {
    _selectedTrack = track;
    VideoPlayerPlatform.instance.setTrackParameters(
      textureId,
      track.width,
      track.height,
      track.bitrate,
    );
  }
}
