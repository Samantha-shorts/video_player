part of 'more_button.dart';

class MoreOptionBottomSheet extends StatefulWidget {
  const MoreOptionBottomSheet({
    super.key,
  });

  static show(BuildContext context) {
    final controller = VideoPlayerController.of(context);
    showModalBottomSheet<void>(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return VideoPlayerControllerProvider(
          controller: controller,
          child: const MoreOptionBottomSheet(),
        );
      },
    );
  }

  @override
  State<MoreOptionBottomSheet> createState() => MoreOptionBottomSheetState();
}

class MoreOptionBottomSheetState
    extends VideoPlayerControllerState<MoreOptionBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return BottomSheetView(
      children: [
        MoreOptionBottomSheetRow(
          icon: controlsConfiguration.playbackSpeedIcon,
          name: "Playback Speed",
          onTap: () {
            controller.controlsEventStreamController.add(
              ControlsEvent(
                  eventType: ControlsEventType.onTapPlaybackSpeedMenu),
            );
            if (!mounted) {
              return;
            }
            Navigator.of(context).pop();
            PlaybackSpeedBottomSheet.show(context);
          },
        ),
        if (controller.subtitlesController.subtitlesSourceList.isNotEmpty)
          MoreOptionBottomSheetRow(
            icon: controlsConfiguration.subtitlesIcon,
            name: "Subtitles",
            onTap: () {
              controller.controlsEventStreamController.add(
                ControlsEvent(eventType: ControlsEventType.onTapSubtitlesMenu),
              );
              if (!mounted) {
                return;
              }
              Navigator.of(context).pop();
              SubtitlesBottomSheet.show(context);
            },
          ),
        MoreOptionBottomSheetRow(
          icon: controlsConfiguration.qualitiesIcon,
          name: "Quality",
          onTap: () {
            controller.controlsEventStreamController.add(
              ControlsEvent(eventType: ControlsEventType.onTapQualityMenu),
            );
            if (!mounted) {
              return;
            }
            Navigator.of(context).pop();
            QualityBottomSheet.show(context);
          },
        ),
      ],
    );
  }
}

class MoreOptionBottomSheetRow extends StatefulWidget {
  const MoreOptionBottomSheetRow({
    Key? key,
    required this.icon,
    required this.name,
    required this.onTap,
  }) : super(key: key);

  final IconData icon;
  final String name;
  final void Function() onTap;

  @override
  State<MoreOptionBottomSheetRow> createState() =>
      MoreOptionBottomSheetRowState();
}

class MoreOptionBottomSheetRowState
    extends VideoPlayerControllerState<MoreOptionBottomSheetRow> {
  @override
  Widget build(BuildContext context) {
    return MaterialClickableWidget(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              widget.icon,
              color: controlsConfiguration.overflowMenuIconsColor,
            ),
            const SizedBox(width: 16),
            Text(
              widget.name,
              style: getOverflowMenuElementTextStyle(false),
            ),
          ],
        ),
      ),
    );
  }
}
