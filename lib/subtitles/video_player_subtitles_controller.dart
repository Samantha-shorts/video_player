import 'dart:async';

import 'package:collection/collection.dart';
import 'package:video_player/abr/abr_subtitle.dart';
import 'package:video_player/subtitles/video_player_subtitle.dart';
import 'package:video_player/subtitles/video_player_subtitles_factory.dart';
import 'package:video_player/subtitles/video_player_subtitles_source.dart';
import 'package:video_player/subtitles/video_player_subtitles_source_type.dart';
import 'package:video_player/utils.dart';

enum SubtitlesStreamEvent {
  didReset,
  sourceListChanged,
  selectedSourceChanged,
}

class VideoPlayerSubtitlesController {
  VideoPlayerSubtitlesController();

  VideoPlayerSubtitlesSource? _selectedSubtitlesSource;

  VideoPlayerSubtitlesSource? get selectedSubtitlesSource =>
      _selectedSubtitlesSource;

  List<VideoPlayerSubtitle> _subtitlesLines = [];

  List<VideoPlayerSubtitle> get subtitlesLines => _subtitlesLines;

  List<VideoPlayerSubtitlesSource> _subtitlesSourceList = [];

  List<VideoPlayerSubtitlesSource> get subtitlesSourceList =>
      _subtitlesSourceList;

  final _subtitlesStreamController =
      StreamController<SubtitlesStreamEvent>.broadcast();

  Stream<SubtitlesStreamEvent> get subtitlesStream =>
      _subtitlesStreamController.stream;

  ///Flag which determines whether are ASMS segments loading
  bool _asmsSegmentsLoading = false;

  ///List of loaded ASMS segments
  final Set<String> _asmsSegmentsLoaded = {};

  bool get isSelectedNone =>
      selectedSubtitlesSource == null ||
      selectedSubtitlesSource?.type == VideoPlayerSubtitlesSourceType.none;

  void reset() {
    _selectedSubtitlesSource = null;
    _subtitlesLines.clear();
    _subtitlesSourceList.clear();
    _asmsSegmentsLoading = false;
    _asmsSegmentsLoaded.clear();
    _subtitlesStreamController.add(SubtitlesStreamEvent.didReset);
  }

  void setSubtitlesSourceList(List<AbrSubtitle> subtitles) {
    _subtitlesSourceList = subtitles
        .map((subtitle) => VideoPlayerSubtitlesSource(
              type: VideoPlayerSubtitlesSourceType.network,
              name: subtitle.name,
              urls: subtitle.realUrls,
              asmsIsSegmented: subtitle.isSegmented,
              asmsSegmentsTime: subtitle.segmentsTime,
              asmsSegments: subtitle.segments,
              selectedByDefault: subtitle.isDefault,
            ))
        .toList();
    _subtitlesSourceList.add(
      VideoPlayerSubtitlesSource(type: VideoPlayerSubtitlesSourceType.none),
    );
    _subtitlesStreamController.add(SubtitlesStreamEvent.sourceListChanged);
  }

  void selectDefaultSource() {
    final defaultSubtitle = _subtitlesSourceList
            .firstWhereOrNull((e) => e.selectedByDefault == true) ??
        _subtitlesSourceList
            .firstWhere((e) => e.type == VideoPlayerSubtitlesSourceType.none);
    setSubtitleSource(defaultSubtitle);
  }

  void setSubtitleSource(VideoPlayerSubtitlesSource source) {
    _subtitlesLines = [];
    _selectedSubtitlesSource = source;
    _subtitlesStreamController.add(SubtitlesStreamEvent.selectedSourceChanged);
  }

  void loadAllSubtitleLines() async {
    if (selectedSubtitlesSource == null) return;
    _subtitlesLines = await VideoPlayerSubtitlesFactory.parseSubtitles(
        selectedSubtitlesSource!);
  }

  ///Load ASMS subtitles segments for given [position].
  ///Segments are being loaded within range (current video position;endPosition)
  ///where endPosition is based on time segment detected in HLS playlist. If
  ///time segment is not present then 5000 ms will be used. Also time segment
  ///is multiplied by 5 to increase window of duration.
  ///Segments are also cached, so same segment won't load twice. Only one
  ///pack of segments can be load at given time.
  Future loadAsmsSubtitlesSegments(Duration position) async {
    try {
      if (_asmsSegmentsLoading) {
        return;
      }
      _asmsSegmentsLoading = true;
      final source = _selectedSubtitlesSource;
      final Duration loadDurationEnd = Duration(
          milliseconds:
              position.inMilliseconds + 5 * (source?.asmsSegmentsTime ?? 5000));

      final segmentsToLoad = source?.asmsSegments
          ?.where((segment) {
            return (segment.startTime <= position &&
                        position <= segment.endTime ||
                    segment.startTime <= loadDurationEnd &&
                        loadDurationEnd <= segment.endTime) &&
                !_asmsSegmentsLoaded.contains(segment.realUrl);
          })
          .map((segment) => segment.realUrl)
          .toList();

      if (segmentsToLoad != null && segmentsToLoad.isNotEmpty) {
        final subtitlesParsed =
            await VideoPlayerSubtitlesFactory.parseSubtitles(
                VideoPlayerSubtitlesSource(
          type: source!.type,
          headers: source.headers,
          urls: segmentsToLoad,
        ));

        ///Additional check if current source of subtitles is same as source
        ///used to start loading subtitles. It can be different when user
        ///changes subtitles and there was already pending load.
        if (source == _selectedSubtitlesSource) {
          subtitlesLines.addAll(subtitlesParsed);
          _asmsSegmentsLoaded.addAll(segmentsToLoad);
        }
      }
      _asmsSegmentsLoading = false;
    } catch (exception) {
      Utils.log("Load ASMS subtitle segments failed: $exception");
    }
  }
}
