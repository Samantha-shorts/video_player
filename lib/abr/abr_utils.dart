import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:video_player/utils.dart';

import 'abr_audio_track.dart';
import 'abr_data_holder.dart';
import 'abr_subtitle.dart';
import 'abr_track.dart';

class AbrUtils {
  static Future<AbrDataHolder> parse(
    String data,
    String masterPlaylistUrl,
  ) async {
    List<AbrTrack> tracks = [];
    List<AbrSubtitle> subtitles = [];
    List<AbrAudioTrack> audios = [];
    try {
      final List<List<dynamic>> list = await Future.wait([
        _parseTracks(data, masterPlaylistUrl),
        _parseSubtitles(data, masterPlaylistUrl),
        _parseLanguages(data, masterPlaylistUrl)
      ]);
      tracks = list[0] as List<AbrTrack>;
      subtitles = list[1] as List<AbrSubtitle>;
      audios = list[2] as List<AbrAudioTrack>;
    } catch (exception) {
      Utils.log("Exception on hls parse: $exception");
    }
    return AbrDataHolder(tracks: tracks, audios: audios, subtitles: subtitles);
  }

  static Future<List<AbrTrack>> _parseTracks(
    String data,
    String masterPlaylistUrl,
  ) async {
    final List<AbrTrack> tracks = [];
    try {
      final parsedPlaylist = await HlsPlaylistParser.create()
          .parseString(Uri.parse(masterPlaylistUrl), data);
      if (parsedPlaylist is HlsMasterPlaylist) {
        parsedPlaylist.variants.forEach(
          (variant) {
            tracks.add(AbrTrack('', variant.format.width, variant.format.height,
                variant.format.bitrate, 0, '', ''));
          },
        );
      }

      if (tracks.isNotEmpty) {
        tracks.insert(0, AbrTrack.defaultTrack());
      }
    } catch (exception) {
      Utils.log("Exception on parseSubtitles: $exception");
    }
    return tracks;
  }

  ///Parse subtitles from provided m3u8 url
  static Future<List<AbrSubtitle>> _parseSubtitles(
    String data,
    String masterPlaylistUrl,
  ) async {
    final List<AbrSubtitle> subtitles = [];
    try {
      final parsedPlaylist = await HlsPlaylistParser.create()
          .parseString(Uri.parse(masterPlaylistUrl), data);

      if (parsedPlaylist is HlsMasterPlaylist) {
        for (final Rendition element in parsedPlaylist.subtitles) {
          final hlsSubtitle = await _parseSubtitlesPlaylist(element);
          if (hlsSubtitle != null) {
            subtitles.add(hlsSubtitle);
          }
        }
      }
    } catch (exception) {
      Utils.log("Exception on parseSubtitles: $exception");
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

      final parsedSubtitle =
          await hlsPlaylistParser.parseString(rendition.url!, subtitleData);
      final hlsMediaPlaylist = parsedSubtitle as HlsMediaPlaylist;
      final hlsSubtitlesUrls = <String>[];

      final List<AbrSubtitleSegment> asmsSegments = [];
      final bool isSegmented = hlsMediaPlaylist.segments.length > 1;
      int microSecondsFromStart = 0;
      for (final Segment segment in hlsMediaPlaylist.segments) {
        final split = rendition.url.toString().split("/");
        var realUrl = "";
        for (var index = 0; index < split.length - 1; index++) {
          // ignore: use_string_buffers
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
      if (parsedSubtitle.targetDurationUs != null) {
        targetDuration = parsedSubtitle.targetDurationUs! ~/ 1000;
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
          isDefault: isDefault);
    } catch (exception) {
      Utils.log("Failed to process subtitles playlist: $exception");
      return null;
    }
  }

  static Future<List<AbrAudioTrack>> _parseLanguages(
    String data,
    String masterPlaylistUrl,
  ) async {
    final List<AbrAudioTrack> audios = [];
    final parsedPlaylist = await HlsPlaylistParser.create()
        .parseString(Uri.parse(masterPlaylistUrl), data);
    if (parsedPlaylist is HlsMasterPlaylist) {
      for (int index = 0; index < parsedPlaylist.audios.length; index++) {
        final Rendition audio = parsedPlaylist.audios[index];
        audios.add(AbrAudioTrack(
          id: index,
          label: audio.name,
          language: audio.format.language,
          url: audio.url.toString(),
        ));
      }
    }

    return audios;
  }
}
