import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:example/constants.dart';

class ScrollVideoPage extends StatefulWidget {
  const ScrollVideoPage({super.key});

  @override
  State<ScrollVideoPage> createState() => _ScrollVideoPageState();
}

class _ScrollVideoPageState extends State<ScrollVideoPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Basic player")),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return _Page(index: index);
        },
        itemCount: 10,
        onPageChanged: (value) {
          print(value);
        },
      ),
    );
  }
}

class _Page extends StatefulWidget {
  const _Page({required this.index});

  final int index;

  @override
  State<_Page> createState() => __PageState();
}

class __PageState extends State<_Page> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    controller.setNetworkDataSource(
      fileUrl: Constants.m3u8_16x9,
      disableRemoteControl: true,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  final controller = VideoPlayerController(
    configuration: VideoPlayerConfiguration(autoPlay: true, autoLoop: true),
  );

  @override
  Widget build(BuildContext context) {
    return VideoPlayer(controller: controller);
  }
}
