import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:video_player/abr/abr.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/controls/controls.dart';
import 'package:video_player/subtitles/subtitles.dart';

part 'more_option_bottom_sheet.dart';
part 'playback_speed_bottom_sheet.dart';
part 'quality_bottom_sheet.dart';
part 'subtitles_bottom_sheet.dart';

extension _VideoPlayerControllerStateExtensions on VideoPlayerControllerState {
  AbrTrack? get selectedTrack => controller.tracksController.selectedTrack;

  TextStyle getOverflowMenuElementTextStyle(bool isSelected) {
    return TextStyle(
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: isSelected
          ? controlsConfiguration.overflowModalTextColor
          : controlsConfiguration.overflowModalTextColor.withOpacity(0.7),
    );
  }
}

class MoreButton extends StatefulWidget {
  const MoreButton({
    super.key,
  });

  @override
  State<MoreButton> createState() => MoreButtonState();
}

class MoreButtonState extends VideoPlayerControllerState<MoreButton> {
  @override
  Widget build(BuildContext context) {
    final controlsConfiguration =
        controller.configuration.controlsConfiguration;
    return MaterialClickableWidget(
      onTap: () {
        MoreOptionBottomSheet.show(context);
        controller.controlsEventStreamController
            .add(ControlsEvent(eventType: ControlsEventType.onTapMore));
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          controlsConfiguration.overflowMenuIcon,
          color: controlsConfiguration.iconsColor,
        ),
      ),
    );
  }
}

class BottomSheetView extends StatelessWidget {
  const BottomSheetView({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ),
    );
  }
}
