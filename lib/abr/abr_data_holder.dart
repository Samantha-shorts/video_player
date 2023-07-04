import 'abr_audio_track.dart';
import 'abr_subtitle.dart';
import 'abr_track.dart';

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
