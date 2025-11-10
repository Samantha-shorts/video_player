part of 'more_button.dart';

class QualityBottomSheet extends StatefulWidget {
  const QualityBottomSheet({
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
          child: const QualityBottomSheet(),
        );
      },
    );
  }

  @override
  State<QualityBottomSheet> createState() => QualityBottomSheetState();
}

class QualityBottomSheetState
    extends VideoPlayerControllerState<QualityBottomSheet> {
  String? defaultQualitySelectable(AbrTrack track) {
    final int width = track.width ?? 0;
    final int height = track.height ?? 0;
    final int bitrate = track.bitrate ?? 0;
    if (width == 0 && height == 0 && bitrate == 0) {
      return "${height}p";
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectableFn = controller.configuration.quarityTrackSelectable ??
        defaultQualitySelectable;

    final enableAbrTracks = [
      for (final track in controller.tracksController.formatAbrTracks)
        (track, selectableFn(track)),
      (AbrTrack.defaultTrack(), 'Auto'),
    ];
    final rows = enableAbrTracks
        .map((e) => QualityBottomSheetStateRow(track: e.$1, displayName: e.$2!))
        .toList();

    return BottomSheetView(
      children: rows,
    );
  }
}

class QualityBottomSheetStateRow extends StatefulWidget {
  const QualityBottomSheetStateRow({
    Key? key,
    required this.track,
    required this.displayName,
  }) : super(key: key);

  final AbrTrack track;
  final String displayName;

  @override
  State<QualityBottomSheetStateRow> createState() =>
      QualityBottomSheetStateRowState();
}

class QualityBottomSheetStateRowState
    extends VideoPlayerControllerState<QualityBottomSheetStateRow> {
  @override
  Widget build(BuildContext context) {
    final bool isSelected =
        (selectedTrack != null && selectedTrack == widget.track) ||
            (selectedTrack == null &&
                widget.track.width == 0 &&
                widget.track.height == 0 &&
                widget.track.bitrate == 0);

    return MaterialClickableWidget(
      onTap: () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
        controller.tracksController.selectTrack(widget.track);
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
              widget.displayName,
              style: getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }
}
