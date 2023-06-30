import 'package:video_player/abr/abr_audio_track.dart';
import 'package:video_player/abr/abr_subtitle.dart';
import 'package:video_player/abr/abr_track.dart';

class AbrDataHolder {
  List<AbrTrack>? tracks;
  List<AbrSubtitle>? subtitles;
  List<AbrAudioTrack>? audios;

  AbrDataHolder({this.tracks, this.subtitles, this.audios});

  @override
  String toString() {
    // ignore: no_runtimetype_tostring
    return '$runtimeType('
        'tracks: $tracks, '
        'subtitles: $subtitles, '
        'audios: $audios'
        ')';
  }
}
