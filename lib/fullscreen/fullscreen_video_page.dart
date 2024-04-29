import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/controller/video_player_controller_state.dart';
import 'package:video_player/controller/video_player_value.dart';
import 'package:video_player/player/video_player_with_controls.dart';

class FullscreenVideoPage extends StatefulWidget {
  const FullscreenVideoPage({super.key});

  @override
  State<FullscreenVideoPage> createState() => FullscreenVideoPageState();
}

class FullscreenVideoPageState
    extends VideoPlayerControllerState<FullscreenVideoPage> {
  @override
  Widget build(BuildContext context) {
    final Widget videoContent;
    if (Platform.isAndroid) {
      final isExpanded = lastValue?.isExpanded ?? false;
      final screenSize = MediaQuery.sizeOf(context);
      final aspectRatio =
          (lastValue?.size?.width ?? 0) / (lastValue?.size?.height ?? 0);
      videoContent = SizedBox(
        width: isExpanded ? screenSize.width : null,
        height: isExpanded ? screenSize.width / aspectRatio : null,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: _buildPlayer(),
        ),
      );
    } else {
      videoContent = _buildPlayer();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        alignment: Alignment.center,
        color: Colors.black,
        child: videoContent,
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.expandChanged;
  }

  Widget _buildPlayer() {
    return VideoPlayerWithControls(
      controller: controller,
    );
  }
}
