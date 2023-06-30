import 'package:flutter/material.dart';
import 'package:video_player/controls/progress_colors.dart';
import 'package:video_player/platform_event.dart';
import 'package:video_player/video_player_controller_state.dart';
import 'package:video_player/video_player_value.dart';

class MaterialVideoProgressBar extends StatefulWidget {
  MaterialVideoProgressBar({
    ProgressColors? colors,
    Key? key,
    required this.dragStart,
    required this.dragEnd,
  })  : colors = colors ?? ProgressColors(),
        super(key: key);

  final ProgressColors colors;
  final VoidCallback dragStart;
  final VoidCallback dragEnd;

  @override
  State<MaterialVideoProgressBar> createState() {
    return _VideoProgressBarState();
  }
}

class _VideoProgressBarState
    extends VideoPlayerControllerState<MaterialVideoProgressBar> {
  Duration? _seekingPosition;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (DragStartDetails details) {
        if (controller.value.initialized != true) {
          return;
        }
        widget.dragStart();
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (controller.value.initialized != true) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
      onHorizontalDragEnd: (DragEndDetails details) async {
        if (controller.value.initialized != true) {
          return;
        }
        await controller.seekTo(_seekingPosition);
        _seekingPosition = null;
        widget.dragEnd();
      },
      child: Center(
        child: Container(
          height: MediaQuery.of(context).size.height / 2,
          width: MediaQuery.of(context).size.width,
          color: Colors.transparent,
          child: CustomPaint(
            painter: _ProgressBarPainter(
              colors: widget.colors,
              position:
                  _seekingPosition ?? lastValue?.position ?? Duration.zero,
              duration: controller.value.duration,
              buffered: controller.value.buffered,
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
    return newValue.eventType == VideoPlayerEventType.initialized ||
        newValue.eventType == VideoPlayerEventType.positionChanged;
  }

  void seekToRelativePosition(Offset globalPosition) async {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject != null) {
      final box = renderObject as RenderBox;
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      if (relative >= 0 && relative <= 1) {
        final Duration position = controller.value.duration! * relative;
        _seekingPosition = position;
        setState(() {});
      }
    }
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter({
    required this.colors,
    required this.position,
    required this.duration,
    this.buffered,
  });

  ProgressColors colors;
  Duration position;
  Duration? duration;
  DurationRange? buffered;

  @override
  bool shouldRepaint(CustomPainter painter) {
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (duration == null) return;

    const height = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, size.height / 2),
          Offset(size.width, size.height / 2 + height),
        ),
        const Radius.circular(4.0),
      ),
      colors.backgroundPaint,
    );

    double playedPartPercent =
        position.inMilliseconds / duration!.inMilliseconds;
    if (playedPartPercent.isNaN) {
      playedPartPercent = 0;
    }
    final double playedPart =
        playedPartPercent > 1 ? size.width : playedPartPercent * size.width;
    if (buffered != null) {
      double start = buffered!.startFraction(duration!) * size.width;
      if (start.isNaN) {
        start = 0;
      }
      double end = buffered!.endFraction(duration!) * size.width;
      if (end.isNaN) {
        end = 0;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(
            Offset(start, size.height / 2),
            Offset(end, size.height / 2 + height),
          ),
          const Radius.circular(4.0),
        ),
        colors.bufferedPaint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, size.height / 2),
          Offset(playedPart, size.height / 2 + height),
        ),
        const Radius.circular(4.0),
      ),
      colors.playedPaint,
    );
    canvas.drawCircle(
      Offset(playedPart, size.height / 2 + height / 2),
      height * 3,
      colors.handlePaint,
    );
  }
}
