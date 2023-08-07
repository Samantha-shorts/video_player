import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_example/constants.dart';

class BasicPlayerPage extends StatefulWidget {
  const BasicPlayerPage({super.key});

  @override
  State<BasicPlayerPage> createState() => _BasicPlayerPageState();
}

class _BasicPlayerPageState extends State<BasicPlayerPage> {
  final controller = VideoPlayerController(
    configuration: VideoPlayerConfiguration(
      autoPlay: false,
    ),
  );

  @override
  void initState() {
    super.initState();
    controller.setNetworkDataSource(
      Constants.m3u8_16x9,
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
        title: const Text("Basic player"),
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
