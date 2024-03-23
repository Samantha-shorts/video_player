import 'package:flutter/material.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/controls/controls.dart';

class ExpandShrinkButton extends StatefulWidget {
  const ExpandShrinkButton({super.key});

  @override
  State<ExpandShrinkButton> createState() => ExpandShrinkButtonState();
}

class ExpandShrinkButtonState extends VideoPlayerControllerState<ExpandShrinkButton> {
  @override
  Widget build(BuildContext context) {
    return MaterialClickableWidget(
      onTap: () async {
        if (lastValue?.isExpanded == true) {
          controller.shrink();
          controller.controlsEventStreamController.add(ControlsEvent(
            eventType: ControlsEventType.onTapExpandShrink,
            expanded: false,
          ));
        } else {
          controller.expand();
          controller.controlsEventStreamController.add(ControlsEvent(
            eventType: ControlsEventType.onTapExpandShrink,
            expanded: true,
          ));
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          lastValue?.isExpanded == true
              ? controlsConfiguration.shrinkIcon
              : controlsConfiguration.expandIcon,
          color: controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.expandChanged;
  }
}
