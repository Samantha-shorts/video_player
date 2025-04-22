import 'dart:async';

import 'package:example/constants.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BasicPlayerPage extends StatefulWidget {
  const BasicPlayerPage({super.key});

  @override
  State<BasicPlayerPage> createState() => _BasicPlayerPageState();
}

class _BasicPlayerPageState extends State<BasicPlayerPage> {
  final controller = VideoPlayerController(
    configuration: VideoPlayerConfiguration(
      autoPlay: false,
      autoLoop: true,
    ),
  );

  StreamSubscription? _controlsEventSubscription;

  @override
  void initState() {
    super.initState();
    controller.setNetworkDataSource(
      fileUrl: Constants.m3u8_16x9,
      notificationConfiguration: const VideoPlayerNotificationConfiguration(
        title: "video example title",
        author: "video author",
      ),
    );
    _controlsEventSubscription = controller.controlsEventStream.listen((event) {
      print(event);
    });
  }

  @override
  void dispose() {
    _controlsEventSubscription?.cancel();
    super.dispose();
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
