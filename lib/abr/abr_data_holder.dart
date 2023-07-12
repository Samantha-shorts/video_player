import 'package:collection/collection.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:video_player/utils.dart';

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
    return '$runtimeType('
        'tracks: $tracks, '
        'subtitles: $subtitles, '
        'audios: $audios'
        ')';
  }

  static Future<AbrDataHolder> parse(
    String masterPlaylistUrl,
    String data,
  ) async {
    final master = await HlsPlaylistParser.create()
        .parseString(Uri.parse(masterPlaylistUrl), data) as HlsMasterPlaylist;
    final list = await Future.wait([
      _parseTracks(master),
      _parseSubtitles(master),
    ]);
    final tracks = list[0] as List<AbrTrack>;
    final subtitles = list[1] as List<AbrSubtitle>;
    final audios = _parseLanguages(master);
    return AbrDataHolder(tracks: tracks, subtitles: subtitles, audios: audios);
  }

  static Future<List<AbrTrack>> _parseTracks(HlsMasterPlaylist master) async {
    final tracks = master.variants
        .map(
          (variant) => AbrTrack('', variant.format.width, variant.format.height,
              variant.format.bitrate, 0, '', ''),
        )
        .toList();
    if (tracks.isNotEmpty) {
      tracks.insert(0, AbrTrack.defaultTrack());
    }
    return tracks;
  }

  static Future<List<AbrSubtitle>> _parseSubtitles(
    HlsMasterPlaylist master,
  ) async {
    final List<AbrSubtitle> subtitles = [];
    for (final Rendition element in master.subtitles) {
      final hlsSubtitle = await _parseSubtitlesPlaylist(element);
      if (hlsSubtitle != null) {
        subtitles.add(hlsSubtitle);
      }
    }
    return subtitles;
  }

  ///Parse HLS subtitles playlist. If subtitles are segmented (more than 1
  ///segment is present in playlist), then setup subtitles as segmented.
  ///Segmented subtitles are loading with JIT policy, when video is playing
  ///to prevent massive load od video start. Segmented subtitles will have
  ///filled segments list which contains start, end and url of subtitles based
  ///on time in playlist.
  static Future<AbrSubtitle?> _parseSubtitlesPlaylist(
    Rendition rendition,
  ) async {
    try {
      final HlsPlaylistParser hlsPlaylistParser = HlsPlaylistParser.create();
      final subtitleData = await Utils.getDataFromUrl(rendition.url.toString());
      if (subtitleData == null) {
        return null;
      }

      final hlsMediaPlaylist = await hlsPlaylistParser.parseString(
        rendition.url!,
        subtitleData,
      ) as HlsMediaPlaylist;

      final hlsSubtitlesUrls = <String>[];

      final List<AbrSubtitleSegment> asmsSegments = [];
      final bool isSegmented = hlsMediaPlaylist.segments.length > 1;
      int microSecondsFromStart = 0;
      for (final segment in hlsMediaPlaylist.segments) {
        final split = rendition.url.toString().split("/");
        var realUrl = "";
        for (var index = 0; index < split.length - 1; index++) {
          realUrl += "${split[index]}/";
        }
        if (segment.url?.startsWith("http") == true) {
          realUrl = segment.url!;
        } else {
          realUrl += segment.url!;
        }
        hlsSubtitlesUrls.add(realUrl);

        if (isSegmented) {
          final int nextMicroSecondsFromStart =
              microSecondsFromStart + segment.durationUs!;
          asmsSegments.add(
            AbrSubtitleSegment(
              startTime: Duration(microseconds: microSecondsFromStart),
              endTime: Duration(microseconds: nextMicroSecondsFromStart),
              realUrl: realUrl,
            ),
          );
          microSecondsFromStart = nextMicroSecondsFromStart;
        }
      }

      int targetDuration = 0;
      if (hlsMediaPlaylist.targetDurationUs != null) {
        targetDuration = hlsMediaPlaylist.targetDurationUs! ~/ 1000;
      }

      bool isDefault = false;

      if (rendition.format.selectionFlags != null) {
        isDefault =
            Utils.checkBitPositionIsSet(rendition.format.selectionFlags!, 1);
      }

      return AbrSubtitle(
        name: rendition.format.label,
        language: rendition.format.language,
        url: rendition.url.toString(),
        realUrls: hlsSubtitlesUrls,
        isSegmented: isSegmented,
        segmentsTime: targetDuration,
        segments: asmsSegments,
        isDefault: isDefault,
      );
    } catch (exception) {
      Utils.log("Failed to process subtitles playlist: $exception");
      return null;
    }
  }

  static List<AbrAudioTrack> _parseLanguages(
    HlsMasterPlaylist master,
  ) =>
      master.audios
          .mapIndexed((index, audio) => AbrAudioTrack(
                id: index,
                label: audio.name,
                language: audio.format.language,
                url: audio.url.toString(),
              ))
          .toList();
}
