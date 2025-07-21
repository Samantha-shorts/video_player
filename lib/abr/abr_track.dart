/// Represents HLS / DASH track which can be played within player
class AbrTrack {
  ///Id of the track
  final String? id;

  ///Width in px of the track
  final int? width;

  ///Height in px of the track
  final int? height;

  ///Bitrate in px of the track
  final int? bitrate;

  ///Frame rate of the track
  final int? frameRate;

  ///Codecs of the track
  final String? codecs;

  AbrTrack({
    this.id,
    this.width,
    this.height,
    this.bitrate,
    this.frameRate,
    this.codecs,
  });

  factory AbrTrack.defaultTrack() {
    return AbrTrack(
      id: '',
      width: 0,
      height: 0,
      bitrate: 0,
      frameRate: 0,
      codecs: '',
    );
  }

  @override
  // ignore: unnecessary_overrides
  int get hashCode => super.hashCode;

  @override
  bool operator ==(Object other) {
    return other is AbrTrack &&
        width == other.width &&
        height == other.height &&
        bitrate == other.bitrate &&
        frameRate == other.frameRate &&
        codecs == other.codecs;
  }

  @override
  String toString() {
    // ignore: no_runtimetype_tostring
    return '$runtimeType('
        'id: $id, '
        'width: $width, '
        'height: $height, '
        'bitrate: $bitrate, '
        'frameRate: $frameRate, '
        'codecs: $codecs, '
        ')';
  }
}
