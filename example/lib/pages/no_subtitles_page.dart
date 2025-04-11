import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_example/constants.dart';

class NoSubtitlesPage extends StatefulWidget {
  const NoSubtitlesPage({super.key});

  @override
  State<NoSubtitlesPage> createState() => _NoSubtitlesPageState();
}

class _NoSubtitlesPageState extends State<NoSubtitlesPage> {
  final controller = VideoPlayerController(
    configuration: VideoPlayerConfiguration(
      autoPlay: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    controller.setNetworkDataSource(
      fileUrl: Constants.no_subtitles,
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
        title: const Text("No Subtitles"),
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
