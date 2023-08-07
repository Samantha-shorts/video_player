import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_example/constants.dart';

class ExternalVttPage extends StatefulWidget {
  const ExternalVttPage({super.key});

  @override
  State<ExternalVttPage> createState() => _ExternalVttPagePageState();
}

class _ExternalVttPagePageState extends State<ExternalVttPage> {
  final controller = VideoPlayerController(
    configuration: VideoPlayerConfiguration(
      autoPlay: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    controller.setNetworkDataSource(
      Constants.m3u8_16x9,
      subtitles: [
        VideoPlayerSubtitlesSource(
          type: VideoPlayerSubtitlesSourceType.network,
          name: "日本語",
          urls: [
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/subtitles/jpn/fileSequence0.webvtt"
          ],
          selectedByDefault: true,
        ),
      ],
      notificationConfiguration: const VideoPlayerNotificationConfiguration(
        title: "video example title",
        author: "video author",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("External VTT"),
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
