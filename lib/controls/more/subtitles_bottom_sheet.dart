part of 'more_button.dart';

class SubtitlesBottomSheet extends StatefulWidget {
  const SubtitlesBottomSheet({
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
          child: const SubtitlesBottomSheet(),
        );
      },
    );
  }

  @override
  State<SubtitlesBottomSheet> createState() => SubtitlesBottomSheetState();
}

class SubtitlesBottomSheetState
    extends VideoPlayerControllerState<SubtitlesBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final subtitles = controller.subtitlesController.subtitlesSourceList;
    final noneSubtitlesElementExists = subtitles.firstWhereOrNull(
            (source) => source.type == VideoPlayerSubtitlesSourceType.none) !=
        null;
    if (!noneSubtitlesElementExists) {
      subtitles.add(VideoPlayerSubtitlesSource(
          type: VideoPlayerSubtitlesSourceType.none, name: 'None'));
    }

    return BottomSheetView(
      children: subtitles
          .asMap()
          .entries
          .map(
            (entry) => SubtitlesBottomSheetRow(
              index: entry.key,
              subtitlesSource: entry.value,
            ),
          )
          .toList(),
    );
  }
}

class SubtitlesBottomSheetRow extends StatefulWidget {
  const SubtitlesBottomSheetRow({
    Key? key,
    required this.index,
    required this.subtitlesSource,
  }) : super(key: key);

  final int index;
  final VideoPlayerSubtitlesSource subtitlesSource;

  @override
  State<SubtitlesBottomSheetRow> createState() =>
      SubtitlesBottomSheetRowState();
}

class SubtitlesBottomSheetRowState
    extends VideoPlayerControllerState<SubtitlesBottomSheetRow> {
  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.subtitlesSource ==
        controller.subtitlesController.selectedSubtitlesSource;

    return MaterialClickableWidget(
      onTap: () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
        controller.subtitlesController
            .setSubtitleSource(widget.index, isUserAction: true);
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
              ),
            ),
            const SizedBox(width: 16),
            Text(
              widget.subtitlesSource.type == VideoPlayerSubtitlesSourceType.none
                  ? "None"
                  : widget.subtitlesSource.name ?? "Default",
              style: getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }
}
