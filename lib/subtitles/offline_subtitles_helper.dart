import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/subtitles/subtitles.dart';

class OfflineSubtitlesHelper {
  static Future<List<String>> downloadSubtitleFiles({
    required List<String> urls,
    required Directory directory,
    Map<String, String>? headers,
  }) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final client = HttpClient();
    final savedPaths = <String>[];
    try {
      for (final url in urls) {
        final uri = Uri.parse(url);
        final req = await client.getUrl(uri);
        headers?.forEach((k, v) {
          req.headers.add(k, v);
        });
        final res = await req.close();
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw HttpException(
              'Failed to download subtitle: $url (${res.statusCode})');
        }
        final bytes = await consolidateHttpClientResponseBytes(res);
        final fileName = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : 'subtitle_${DateTime.now().millisecondsSinceEpoch}.vtt';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        savedPaths.add(file.path);
      }
      return savedPaths;
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, String>> downloadSubtitleFilesByLocale({
    required Map<String, String> urlsByLocale,
    required Directory directory,
    Map<String, String>? headers,
  }) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    String sanitizeLocale(String locale) =>
        locale.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

    String withLocaleSuffix(String fileName, String locale) {
      final idx = fileName.lastIndexOf('.');
      final base = idx > 0 ? fileName.substring(0, idx) : fileName;
      final ext = idx > 0 ? fileName.substring(idx) : '';
      final safeLocale = sanitizeLocale(locale);
      return '${base}__$safeLocale$ext';
    }

    final client = HttpClient();
    final saved = <String, String>{};
    try {
      for (final entry in urlsByLocale.entries) {
        final locale = entry.key;
        final url = entry.value;
        final uri = Uri.parse(url);

        final req = await client.getUrl(uri);
        headers?.forEach((k, v) {
          req.headers.add(k, v);
        });
        final res = await req.close();
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw HttpException(
              'Failed to download subtitle: $url (${res.statusCode})');
        }
        final bytes = await consolidateHttpClientResponseBytes(res);
        final originalName = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : 'subtitle_${DateTime.now().millisecondsSinceEpoch}.vtt';
        final fileName = withLocaleSuffix(originalName, locale);
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        saved[locale] = file.path;
      }
      return saved;
    } finally {
      client.close(force: true);
    }
  }

  static List<VideoPlayerSubtitlesSource> buildFileSources({
    required List<String> paths,
    String name = 'Subtitles',
  }) {
    if (paths.isEmpty) return const [];
    return [
      VideoPlayerSubtitlesSource(
        type: VideoPlayerSubtitlesSourceType.file,
        name: name,
        urls: paths,
        selectedByDefault: true,
      )
    ];
  }

  static Future<void> attachToOffline({
    required VideoPlayerController controller,
    required String offlineKey,
    required List<String> subtitleUrls,
    required Directory directory,
    Map<String, String>? headers,
    String name = 'Subtitles',
    Duration? startPosition,
  }) async {
    final paths = await downloadSubtitleFiles(
      urls: subtitleUrls,
      directory: directory,
      headers: headers,
    );
    final sources = buildFileSources(paths: paths, name: name);
    await controller.setOfflineDataSource(
      offlineKey,
      startPosition: startPosition,
      subtitles: sources,
      headers: headers,
    );
  }
}
