import 'package:flutter/material.dart';
import 'package:video_player/controls/progress_colors.dart';
import 'package:video_player/platform/platform.dart';

class ProgressBarPainter extends CustomPainter {
  ProgressBarPainter({
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
