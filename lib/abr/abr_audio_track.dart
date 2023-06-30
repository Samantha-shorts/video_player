///Representation of HLS / DASH audio track
class AbrAudioTrack {
  ///Audio index in DASH xml or Id of track inside HLS playlist
  final int? id;

  ///segmentAlignment
  final bool? segmentAlignment;

  ///Description of the audio
  final String? label;

  ///Language code
  final String? language;

  ///Url of audio track
  final String? url;

  ///mimeType of the audio track
  final String? mimeType;

  AbrAudioTrack({
    this.id,
    this.segmentAlignment,
    this.label,
    this.language,
    this.url,
    this.mimeType,
  });

  @override
  String toString() {
    // ignore: no_runtimetype_tostring
    return '$runtimeType('
        'id: $id, '
        'segmentAlignment: $segmentAlignment, '
        'label: $label, '
        'language: $language, '
        'url: $url, '
        'mimeType: $mimeType)';
  }
}
