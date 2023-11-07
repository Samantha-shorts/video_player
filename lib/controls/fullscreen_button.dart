import 'package:flutter/material.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/controls/controls.dart';

class FullscreenButton extends StatefulWidget {
  const FullscreenButton({super.key});

  @override
  State<FullscreenButton> createState() => FullscreenButtonState();
}

class FullscreenButtonState
    extends VideoPlayerControllerState<FullscreenButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: MaterialClickableWidget(
        onTap: () {
          if (lastValue?.isFullscreen != true) {
            controller.enterFullscreen();
            controller.controlsEventStreamController.add(ControlsEvent(
              eventType: ControlsEventType.onTapFullscreen,
              fullscreenEnabled: true,
            ));
          } else {
            controller.exitFullscreen();
            controller.controlsEventStreamController.add(ControlsEvent(
              eventType: ControlsEventType.onTapFullscreen,
              fullscreenEnabled: false,
            ));
          }
        },
        child: Container(
          height: controlsConfiguration.controlBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Center(
            child: Icon(
              lastValue?.isFullscreen == true
                  ? controlsConfiguration.fullscreenDisableIcon
                  : controlsConfiguration.fullscreenEnableIcon,
              color: controlsConfiguration.iconsColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool willRebuild(
    VideoPlayerValue? oldValue,
    VideoPlayerValue newValue,
  ) {
    return newValue.eventType == VideoPlayerEventType.fullscreenChanged;
  }
}
