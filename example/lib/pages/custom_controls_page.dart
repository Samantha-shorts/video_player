import 'package:flutter/material.dart';
import 'package:video_player/controls/controls.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_example/constants.dart';

class CustomControlsPage extends StatefulWidget {
  const CustomControlsPage({super.key});

  @override
  State<CustomControlsPage> createState() => _CustomControlsPageState();
}

class _CustomControlsPageState extends State<CustomControlsPage> {
  final controller = VideoPlayerController(
    configuration: VideoPlayerConfiguration(
      autoPlay: true,
      hidesControls: true,
      controlsConfiguration: VideoPlayerControlsConfiguration(
        disableSeek: true,
        progressBarPlayedColor: Colors.yellow[600]!,
        progressBarHandleColor: Colors.yellow[600]!,
        progressBarBackgroundColor: Colors.black38,
        iconsColor: Colors.black87,
      ),
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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Custom Controls"),
      ),
      body: VideoPlayerControllerProvider(
        controller: controller,
        child: Column(
          children: [
            const SizedBox(height: 8),
            const MoreButton(),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoPlayer(
                controller: controller,
                noProvider: true,
              ),
            ),
            SizedBox(
              height: 42,
              child: MaterialVideoProgressBar(),
            ),
          ],
        ),
      ),
    );
  }
}
