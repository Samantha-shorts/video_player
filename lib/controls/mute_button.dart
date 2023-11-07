import 'package:flutter/material.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/controls/controls.dart';

class MuteButton extends StatefulWidget {
  const MuteButton({super.key});

  @override
  State<MuteButton> createState() => MuteButtonState();
}

class MuteButtonState extends VideoPlayerControllerState<MuteButton> {
  @override
  Widget build(BuildContext context) {
    return MaterialClickableWidget(
      onTap: () {
        if (lastValue?.isMuted == true) {
          controller.setMuted(false);
          controller.controlsEventStreamController.add(ControlsEvent(
            eventType: ControlsEventType.onTapMute,
            muteOn: false,
          ));
        } else {
          controller.setMuted(true);
          controller.controlsEventStreamController.add(ControlsEvent(
            eventType: ControlsEventType.onTapMute,
            muteOn: true,
          ));
        }
      },
      child: ClipRect(
        child: Container(
          height: controlsConfiguration.controlBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            lastValue?.isMuted != true
                ? controlsConfiguration.muteIcon
                : controlsConfiguration.unMuteIcon,
            color: controlsConfiguration.iconsColor,
          ),
        ),
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.muteChanged;
  }
}
