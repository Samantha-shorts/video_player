import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:video_player/platform/platform.dart';
import 'package:video_player/video_player.dart';

class DownloadHlsPage extends StatefulWidget {
  const DownloadHlsPage({super.key});

  @override
  State<DownloadHlsPage> createState() => _DownloadHlsPageState();
}

enum DownloadStatus {
  notDownloaded,
  loading,
  running,
  suspended,
  canceling,
  completed,
  error
}

class DownloadState {
  DownloadState({
    required this.status,
    this.progress,
  });

  DownloadStatus status;
  double? progress;
}

class _DownloadHlsPageState extends State<DownloadHlsPage> {
  static List<Map<String, String>> list = [
    {
      "name": "test",
      "uri":
          "https://d1qg19f7rqukzl.cloudfront.net/big_buck_bunny_dev_20240917/HLS/big_buck_bunny_1080p_h264.m3u8"
    },
    {
      "name": "Apple 4x3 basic stream (TS)",
      "uri":
          "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"
    },
    {
      "name": "Apple 16x9 basic stream (TS)",
      "uri":
          "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
    },
    {
      "name": "Apple multivariant playlist advanced (TS)",
      "uri":
          "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
    },
    {
      "name": "Apple multivariant playlist advanced (FMP4)",
      "uri":
          "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    },
    {
      "name": "Apple media playlist (TS)",
      "uri":
          "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8"
    },
    {
      "name": "Apple media playlist (AAC)",
      "uri":
          "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear0/prog_index.m3u8"
    },
  ];

  Map<String, DownloadState> states = Map.fromEntries(
    list.map(
      (map) => MapEntry(
        map["uri"] as String,
        DownloadState(status: DownloadStatus.notDownloaded),
      ),
    ),
  );

  late StreamSubscription<PlatformDownloadEvent> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = VideoPlayerPlatform.instance
        .downloadEventStream()
        .listen((event) async {
      switch (event.eventType) {
        case PlatformDownloadEventType.finished:
          final key = event.key!;
          setState(() {
            states[key]?.progress = null;
            states[key]?.status = DownloadStatus.completed;
          });
          break;
        case PlatformDownloadEventType.progress:
          final key = event.key!;
          setState(() {
            states[key]?.progress = event.progress;
            states[key]?.status = DownloadStatus.running;
          });
          break;
        case PlatformDownloadEventType.canceled:
          final key = event.key!;
          setState(() {
            states[key]?.progress = null;
            states[key]?.status = DownloadStatus.notDownloaded;
          });
          break;
        case PlatformDownloadEventType.paused:
          final key = event.key!;
          setState(() {
            states[key]?.status = DownloadStatus.suspended;
          });
          break;
        case PlatformDownloadEventType.resumed:
          final key = event.key!;
          setState(() {
            states[key]?.status = DownloadStatus.loading;
          });
          break;
        default:
          break;
      }
    });
    loadDownloadedURLs();
  }

  DownloadStatus downloadStatusFromState(PlatformDownloadState state) {
    switch (state) {
      case PlatformDownloadState.running:
        return DownloadStatus.running;
      case PlatformDownloadState.suspended:
        return DownloadStatus.suspended;
      case PlatformDownloadState.canceling:
        return DownloadStatus.canceling;
      case PlatformDownloadState.completed:
        return DownloadStatus.completed;
    }
  }

  Future<void> loadDownloadedURLs() async {
    final downloads = await VideoPlayerPlatform.instance.getDownloads();
    for (final entry in downloads) {
      final key = entry.key;
      final downloadState = entry.state;
      states[key]!.status = downloadStatusFromState(downloadState);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> tapAction(int index) async {
    final key = list[index]["uri"]!;
    final state = states[key]!;
    switch (state.status) {
      case DownloadStatus.notDownloaded:
        await onTapDownload(list[index]['uri']!, state);
        break;
      case DownloadStatus.running:
        await VideoPlayerPlatform.instance.pauseDownload(key);
        break;
      case DownloadStatus.suspended:
        await VideoPlayerPlatform.instance.resumeDownload(key);
        break;
      case DownloadStatus.completed:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _PlayPage(offlineKey: key),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> longTapAction(int index) async {
    final key = list[index]["uri"]!;
    final state = states[key]!;
    switch (state.status) {
      case DownloadStatus.running:
      case DownloadStatus.suspended:
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("Cancel download?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await VideoPlayerPlatform.instance.cancelDownload(key);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Download HLS"),
      ),
      body: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (context, index) => const Divider(
          color: Colors.grey,
          thickness: 0.5,
        ),
        itemBuilder: (context, index) {
          final key = list[index]["uri"]!;
          final state = states[key]!;
          return ListTile(
            title: Text(list[index]['name']!),
            trailing: state.status == DownloadStatus.loading ||
                    state.status == DownloadStatus.running
                ? SizedBox(
                    child: state.status == DownloadStatus.running
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(value: state.progress),
                              const Icon(Icons.pause),
                            ],
                          )
                        : const CircularProgressIndicator(),
                  )
                : IconButton(
                    icon: Icon(
                      state.status == DownloadStatus.notDownloaded
                          ? Icons.download
                          : state.status == DownloadStatus.completed
                              ? Icons.delete
                              : state.status == DownloadStatus.suspended
                                  ? Icons.restart_alt
                                  : Icons.error,
                    ),
                    onPressed: () async {
                      if (state.status == DownloadStatus.completed) {
                        await VideoPlayerPlatform.instance
                            .deleteOfflineAsset(key);
                        setState(() {
                          state.status = DownloadStatus.notDownloaded;
                        });
                      } else {
                        await tapAction(index);
                      }
                    },
                  ),
            onTap: () => tapAction(index),
            onLongPress: () => longTapAction(index),
          );
        },
      ),
    );
  }

  Future<void> onTapDownload(String uri, DownloadState state) async {
    setState(() {
      state.status = DownloadStatus.loading;
    });

    final url = await VariantSelector.select(uri, (variants) async {
      return showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: variants.map(
            (variant) {
              return CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.of(context).pop(variant);
                },
                child: Text(formatVariant(variant)),
              );
            },
          ).toList(),
        ),
      );
    });
    if (url != null) {
      await VideoPlayerPlatform.instance.downloadOfflineAsset(
        key: uri,
        url: url.toString(),
        quality: DownloadQuality.high,
      );
    } else {
      setState(() {
        state.status = DownloadStatus.notDownloaded;
      });
    }
  }

  static bool containsVideoCodec(String codecs) {
    var videoCodecs = ['avc1', 'hev1', 'hvc1', 'vp9', 'av01'];
    return videoCodecs.any((codec) => codecs.contains(codec));
  }

  static String formatBitrate(int bitrate) {
    if (bitrate < 1000) {
      return '$bitrate bps';
    } else if (bitrate < 1000000) {
      return '${(bitrate / 1000).toStringAsFixed(1)} kbps';
    } else {
      return '${(bitrate / 1000000).toStringAsFixed(2)} Mbps';
    }
  }

  static String formatVariant(Variant variant) {
    final containsVideo = containsVideoCodec(variant.format.codecs ?? '');
    String text = variant.format.height != null && variant.format.height! > 0
        ? "${variant.format.height}p"
        : formatBitrate(variant.format.bitrate ?? 0);
    if (!containsVideo) {
      text += " (Audio)";
    }
    return text;
  }
}

class VariantSelector {
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  static Future<String?> select<T>(
    String uri,
    Future<Variant?> Function(List<Variant> variants) fn,
  ) async {
    final data = await getDataFromUrlString(uri, null);
    final url = Uri.parse(uri);
    final playlist = await HlsPlaylistParser.create().parseString(url, data);
    if (playlist is HlsMasterPlaylist) {
      final variant = await fn(playlist.variants);
      return variant?.url.toString();
    } else if (playlist is HlsMediaPlaylist) {
      return uri;
    }
    return null;
  }

  static Future<String> getDataFromUrlString(
    String url,
    Map<String, String?>? headers,
  ) async {
    return getDataFromUrl(Uri.parse(url), headers);
  }

  static Future<String> getDataFromUrl(
    Uri url,
    Map<String, String?>? headers,
  ) async {
    final request = await _httpClient.getUrl(url);
    if (headers != null) {
      headers.forEach((name, value) => request.headers.add(name, value!));
    }

    final response = await request.close();
    var data = "";
    await response.transform(const Utf8Decoder()).listen((content) {
      data += content.toString();
    }).asFuture<String?>();

    return data;
  }
}

class _PlayPage extends StatelessWidget {
  const _PlayPage({
    required this.offlineKey,
  });

  final String offlineKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayer.offline(offlineKey),
        ),
      ]),
    );
  }
}
