import 'dart:convert';
import 'dart:io';

import 'package:video_player/subtitles/video_player_subtitles_source.dart';
import 'package:video_player/subtitles/video_player_subtitles_source_type.dart';
import 'package:video_player/utils.dart';

import 'video_player_subtitle.dart';

class VideoPlayerSubtitlesFactory {
  static Future<List<VideoPlayerSubtitle>> parseSubtitles(
      VideoPlayerSubtitlesSource source) async {
    switch (source.type) {
      case VideoPlayerSubtitlesSourceType.file:
        return _parseSubtitlesFromFile(source);
      case VideoPlayerSubtitlesSourceType.network:
        return _parseSubtitlesFromNetwork(source);
      case VideoPlayerSubtitlesSourceType.memory:
        return _parseSubtitlesFromMemory(source);
      default:
        return [];
    }
  }

  static Future<List<VideoPlayerSubtitle>> _parseSubtitlesFromFile(
      VideoPlayerSubtitlesSource source) async {
    try {
      final List<VideoPlayerSubtitle> subtitles = [];
      for (final String? url in source.urls!) {
        final file = File(url!);
        if (file.existsSync()) {
          final String fileContent = await file.readAsString();
          final subtitlesCache = _parseString(fileContent);
          subtitles.addAll(subtitlesCache);
        } else {
          Utils.log("$url doesn't exist!");
        }
      }
      return subtitles;
    } catch (exception) {
      Utils.log("Failed to read subtitles from file: $exception");
    }
    return [];
  }

  static Future<List<VideoPlayerSubtitle>> _parseSubtitlesFromNetwork(
      VideoPlayerSubtitlesSource source) async {
    try {
      final client = HttpClient();
      final List<VideoPlayerSubtitle> subtitles = [];
      for (final String? url in source.urls!) {
        final request = await client.getUrl(Uri.parse(url!));
        source.headers?.keys.forEach((key) {
          final value = source.headers![key];
          if (value != null) {
            request.headers.add(key, value);
          }
        });
        final response = await request.close();
        final data = await response.transform(const Utf8Decoder()).join();
        final cacheList = _parseString(data);
        subtitles.addAll(cacheList);
      }
      client.close();

      Utils.log("Parsed total subtitles: ${subtitles.length}");
      return subtitles;
    } catch (exception) {
      Utils.log("Failed to read subtitles from network: $exception");
    }
    return [];
  }

  static List<VideoPlayerSubtitle> _parseSubtitlesFromMemory(
      VideoPlayerSubtitlesSource source) {
    try {
      return _parseString(source.content!);
    } catch (exception) {
      Utils.log("Failed to read subtitles from memory: $exception");
    }
    return [];
  }

  static List<VideoPlayerSubtitle> _parseString(String value) {
    List<String> components = value.split('\r\n\r\n');
    if (components.length == 1) {
      components = value.split('\n\n');
    }

    // Skip parsing files with no cues
    if (components.length == 1) {
      return [];
    }

    final List<VideoPlayerSubtitle> subtitlesObj = [];

    final bool isWebVTT = components.contains("WEBVTT");
    for (final component in components) {
      if (component.isEmpty) {
        continue;
      }
      final subtitle = VideoPlayerSubtitle(component, isWebVTT);
      if (subtitle.start != null &&
          subtitle.end != null &&
          subtitle.texts != null) {
        subtitlesObj.add(subtitle);
      }
    }

    return subtitlesObj;
  }
}
