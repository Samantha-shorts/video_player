///Representation of HLS / DASH subtitle element.
class AbrSubtitle {
  ///Language of the subtitle
  final String? language;

  ///Name of the subtitle
  final String? name;

  ///MimeType of the subtitle (DASH only)
  final String? mimeType;

  ///Segment alignment (DASH only)
  final bool? segmentAlignment;

  ///Url of the subtitle (master playlist)
  final String? url;

  ///Urls of specific files
  final List<String>? realUrls;

  ///Should subtitles be loaded with segments.
  final bool? isSegmented;

  ///Max value between segments. In HLS defined as #EXT-X-TARGETDURATION.
  ///Only used when [isSegmented] is true.
  final int? segmentsTime;

  ///List of subtitle segments. Only used when [isSegmented] is true.
  final List<AbrSubtitleSegment>? segments;

  ///If the subtitle is the default
  final bool? isDefault;

  AbrSubtitle({
    this.language,
    this.name,
    this.mimeType,
    this.segmentAlignment,
    this.url,
    this.realUrls,
    this.isSegmented,
    this.segmentsTime,
    this.segments,
    this.isDefault,
  });

  @override
  String toString() {
    // ignore: no_runtimetype_tostring
    return '$runtimeType('
        'language: $language, '
        'name: $name, '
        'mimeType: $mimeType, '
        'segmentAlignment: $segmentAlignment, '
        'url: $url, '
        'realUrls: $realUrls, '
        'isSegmented: $isSegmented, '
        'segmentsTime: $segmentsTime, '
        'segments: $segments, '
        'isDefault: $isDefault'
        ')';
  }
}

///Class which represents one segment of subtitles. It consists of start time
///and end time which are relative from start of the video and real url of the
///video (with domain and all paths).
class AbrSubtitleSegment {
  ///Start of the subtitles counting from the start of the video.
  final Duration startTime;

  ///End of the subtitles counting from the start of the video.
  final Duration endTime;

  ///Real url of the subtitles (with all domains and paths).
  final String realUrl;

  AbrSubtitleSegment({
    required this.startTime,
    required this.endTime,
    required this.realUrl,
  });
}
