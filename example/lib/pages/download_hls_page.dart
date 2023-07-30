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

enum DownloadStatus { notDownloaded, loading, progress, finished, error }

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
            states[key]?.status = DownloadStatus.finished;
          });
        case PlatformDownloadEventType.progress:
          final key = event.key!;
          setState(() {
            states[key]?.progress = event.progress;
            states[key]?.status = DownloadStatus.progress;
          });
        default:
          break;
      }
    });
    loadDownloadedURLs();
  }

  Future<void> loadDownloadedURLs() async {
    final downloads = await VideoPlayerPlatform.instance.getDownloads();
    for (final entry in downloads.entries) {
      final key = entry.key;
      final status = entry.value["state"] as int;
      final state = states[key]!;
      switch (status) {
        case 0:
          state.status = DownloadStatus.progress;
          break;
        case 3:
          state.status = DownloadStatus.finished;
          break;
        default:
          break;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
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
                    state.status == DownloadStatus.progress
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: state.status == DownloadStatus.progress
                          ? state.progress
                          : null,
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      state.status == DownloadStatus.notDownloaded
                          ? Icons.download
                          : Icons.delete,
                    ),
                    onPressed: () async {
                      switch (state.status) {
                        case DownloadStatus.notDownloaded:
                          await onTapDownload(list[index]['uri']!, state);
                          break;
                        case DownloadStatus.finished:
                          await VideoPlayerPlatform.instance
                              .deleteOfflineAsset(key);
                          setState(() {
                            state.status = DownloadStatus.notDownloaded;
                          });
                          break;
                        default:
                          break;
                      }
                    },
                  ),
            onTap: () async {
              switch (state.status) {
                case DownloadStatus.notDownloaded:
                  await onTapDownload(list[index]['uri']!, state);
                  break;
                case DownloadStatus.finished:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => _PlayPage(offlineKey: key),
                    ),
                  );
                  break;
                default:
                  break;
              }
            },
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
        uri: url.toString(),
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
    super.key,
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
