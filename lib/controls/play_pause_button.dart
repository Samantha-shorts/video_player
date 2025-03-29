import 'package:flutter/material.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/controls/controls.dart';

class PlayPauseButton extends StatefulWidget {
  const PlayPauseButton({super.key});

  @override
  State<PlayPauseButton> createState() => PlayPauseButtonState();
}

class PlayPauseButtonState extends VideoPlayerControllerState<PlayPauseButton> {
  @override
  Widget build(BuildContext context) {
    return MaterialClickableWidget(
      onTap: () async {
        if (lastValue?.isPlaying == true) {
          controller.pause();
          controller.controlsEventStreamController
              .add(ControlsEvent(eventType: ControlsEventType.onTapPause));
        } else if (lastValue?.isFinished == true) {
          await controller.seekTo(Duration.zero);
          controller.play();
          controller.controlsEventStreamController
              .add(ControlsEvent(eventType: ControlsEventType.onTapReplay));
        } else {
          controller.play();
          controller.controlsEventStreamController
              .add(ControlsEvent(eventType: ControlsEventType.onTapPlay));
        }
      },
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          lastValue?.isPlaying == true
              ? controlsConfiguration.pauseIcon
              : controlsConfiguration.playIcon,
          color: controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.isPlayingChanged;
  }
}
