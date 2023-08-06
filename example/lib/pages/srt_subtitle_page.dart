import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_example/constants.dart';

class SrtSubtitlePage extends StatefulWidget {
  const SrtSubtitlePage({super.key});

  @override
  State<SrtSubtitlePage> createState() => _SrtSubtitlePageState();
}

class _SrtSubtitlePageState extends State<SrtSubtitlePage> {
  final controller = VideoPlayerController(
    configuration: const VideoPlayerConfiguration(
      autoPlay: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    controller.setNetworkDataSource(
      // Constants.m3u8_16x9,
      "https://d173fw6w6ru1im.cloudfront.net/converted/28/a3b31217ac79a02b009f7c22c6bfdff2.m3u8",
      useAbrSubtitles: false,
      subtitles: [
        VideoPlayerSubtitlesSource(
          type: VideoPlayerSubtitlesSourceType.network,
          name: "日本語",
          urls: [Constants.srt_ja],
          selectedByDefault: true,
        ),
        VideoPlayerSubtitlesSource(
          type: VideoPlayerSubtitlesSourceType.network,
          name: "English",
          urls: [Constants.srt_en],
        ),
      ],
      notificationConfiguration: const VideoPlayerNotificationConfiguration(
        title: "video example title",
        author: "video author",
      ),
    );

    controller.addListener(() {
      switch (controller.value.eventType) {
        case VideoPlayerEventType.pipChanged:
          if (Platform.isIOS) {
            controller.selectLegibleMediaGroup();
          }
          break;
        default:
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SRT Subtitle"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayer(controller: controller),
          ),
        ],
      ),
    );
  }
}
