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

enum DownloadState { notDownloaded, loading, progress, finished, error }

class DownloadStateValue {
  DownloadStateValue({
    required this.state,
    this.progress,
    this.downloadingUrl,
  });

  DownloadState state;
  double? progress;
  String? downloadingUrl;
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

  List<DownloadStateValue> states = list
      .map((_) => DownloadStateValue(state: DownloadState.notDownloaded))
      .toList();

  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  late StreamSubscription<PlatformDownloadEvent> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = VideoPlayerPlatform.instance
        .downloadEventStream()
        .listen((event) async {
      switch (event.eventType) {
        case PlatformDownloadEventType.finished:
          final url = event.url!;
          final value =
              states.firstWhere((element) => element.downloadingUrl == url);
          setState(() {
            value.state = DownloadState.finished;
          });
        case PlatformDownloadEventType.progress:
          final url = event.url!;
          final value =
              states.firstWhere((element) => element.downloadingUrl == url);
          setState(() {
            value.state = DownloadState.progress;
            value.progress = event.progress;
          });
        default:
          break;
      }
    });
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
          return ListTile(
            title: Text(list[index]['name']!),
            trailing: states[index].state == DownloadState.loading ||
                    states[index].state == DownloadState.progress
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: states[index].state == DownloadState.progress
                          ? states[index].progress
                          : null,
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      states[index].state == DownloadState.notDownloaded
                          ? Icons.download
                          : Icons.delete,
                    ),
                    onPressed: () async {
                      switch (states[index].state) {
                        case DownloadState.notDownloaded:
                          await onTapDownload(
                              list[index]['uri']!, states[index]);
                          break;
                        case DownloadState.finished:
                          await VideoPlayerPlatform.instance.deleteOfflineAsset(
                              states[index].downloadingUrl!);
                          setState(() {
                            states[index].downloadingUrl = null;
                            states[index].state = DownloadState.notDownloaded;
                          });
                          break;
                        default:
                          break;
                      }
                    },
                  ),
            onTap: () {
              switch (states[index].state) {
                case DownloadState.finished:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          _PlayPage(url: states[index].downloadingUrl!),
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

  Future<void> onTapDownload(String uri, DownloadStateValue value) async {
    setState(() {
      value.state = DownloadState.loading;
    });

    final data = await getDataFromUrlString(uri, null);
    final url = Uri.parse(uri);
    final playlist = await HlsPlaylistParser.create().parseString(url, data);
    if (playlist is HlsMasterPlaylist) {
      final uri = await selectQuality<Uri>(playlist);
      if (uri == null) {
        setState(() {
          value.state = DownloadState.notDownloaded;
        });
      } else {
        VideoPlayerPlatform.instance.downloadOfflineAsset(uri.toString(), null);
        value.downloadingUrl = uri.toString();
      }
    } else if (playlist is HlsMediaPlaylist) {
      VideoPlayerPlatform.instance.downloadOfflineAsset(uri.toString(), null);
      value.downloadingUrl = uri.toString();
    }
  }

  bool containsVideoCodec(String codecs) {
    var videoCodecs = ['avc1', 'hev1', 'hvc1', 'vp9', 'av01'];
    return videoCodecs.any((codec) => codecs.contains(codec));
  }

  Future<T?> selectQuality<T>(HlsMasterPlaylist playlist) async {
    final tracks = playlist.variants
        .where((variant) => containsVideoCodec(variant.format.codecs ?? ''));
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Download movie"),
        message: const Text("Select resolution"),
        actions: tracks
            .map(
              (variant) => CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.of(context).pop(variant.url);
                },
                child: Text(
                    variant.format.height != null && variant.format.height! > 0
                        ? "${variant.format.height}p"
                        : "Bitrate ${variant.format.bitrate}"),
              ),
            )
            .toList(),
      ),
    );
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
    required this.url,
  });

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayer.offline(url),
        ),
      ]),
    );
  }
}
