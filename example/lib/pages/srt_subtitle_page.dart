import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_example/constants.dart';

class SrtSubtitlePage extends StatefulWidget {
  const SrtSubtitlePage({super.key});

  @override
  State<SrtSubtitlePage> createState() => _SrtSubtitlePageState();
}

class _SrtSubtitlePageState extends State<SrtSubtitlePage> {
  @override
  Widget build(BuildContext context) {
    final controller = VideoPlayerController(
      configuration: const VideoPlayerConfiguration(
        autoPlay: true,
      ),
    );
    controller.setNetworkDataSource(
      Constants.m3u8_16x9,
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
