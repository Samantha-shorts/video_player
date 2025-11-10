part of 'more_button.dart';

class PlaybackSpeedBottomSheet extends StatefulWidget {
  const PlaybackSpeedBottomSheet({
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
          child: const PlaybackSpeedBottomSheet(),
        );
      },
    );
  }

  @override
  State<PlaybackSpeedBottomSheet> createState() =>
      PlaybackSpeedBottomSheetState();
}

class PlaybackSpeedBottomSheetState
    extends VideoPlayerControllerState<PlaybackSpeedBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return const BottomSheetView(
      children: [
        PlaybackSpeedBottomSheetRow(value: 0.25),
        PlaybackSpeedBottomSheetRow(value: 0.5),
        PlaybackSpeedBottomSheetRow(value: 0.75),
        PlaybackSpeedBottomSheetRow(value: 1.0),
        PlaybackSpeedBottomSheetRow(value: 1.25),
        PlaybackSpeedBottomSheetRow(value: 1.5),
        PlaybackSpeedBottomSheetRow(value: 1.75),
        PlaybackSpeedBottomSheetRow(value: 2.0),
      ],
    );
  }
}

class PlaybackSpeedBottomSheetRow extends StatefulWidget {
  const PlaybackSpeedBottomSheetRow({
    Key? key,
    required this.value,
  }) : super(key: key);

  final double value;

  @override
  State<PlaybackSpeedBottomSheetRow> createState() =>
      _PlaybackSpeedBottomSheetRowState();
}

class _PlaybackSpeedBottomSheetRowState
    extends VideoPlayerControllerState<PlaybackSpeedBottomSheetRow> {
  @override
  Widget build(BuildContext context) {
    final bool isSelected = lastValue?.playbackRate == widget.value;

    return MaterialClickableWidget(
      onTap: () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
        controller.setPlaybackRate(widget.value);
        controller.controlsEventStreamController.add(
          ControlsEvent(
            eventType: ControlsEventType.onTapPlaybackSpeedValue,
            speedValue: widget.value,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color: controlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              "${widget.value} x",
              style: getOverflowMenuElementTextStyle(isSelected),
            )
          ],
        ),
      ),
    );
  }
}
