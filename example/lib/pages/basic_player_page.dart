import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_example/constants.dart';

class BasicPlayerPage extends StatefulWidget {
  @override
  _BasicPlayerPageState createState() => _BasicPlayerPageState();
}

class _BasicPlayerPageState extends State<BasicPlayerPage> {
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
            child: VideoPlayer.network(Constants.m3u8_16x9),
          ),
        ],
      ),
    );
  }
}
