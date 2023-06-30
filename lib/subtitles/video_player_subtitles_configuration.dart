// Flutter imports:
import 'package:flutter/material.dart';

///Configuration of subtitles - colors/padding/font.
class VideoPlayerSubtitlesConfiguration {
  ///Subtitle font size
  final double fontSize;

  final double fontSizeInFullscreen;

  ///Subtitle font color
  final Color fontColor;

  ///Color of the outline stroke
  final Color outlineColor;

  ///Outline stroke size
  final double outlineSize;

  ///Font family of the subtitle
  final String fontFamily;

  ///Left padding of the subtitle
  final double leftPadding;

  ///Right padding of the subtitle
  final double rightPadding;

  ///Bottom padding of the subtitle
  final double bottomPadding;

  ///Background color of the subtitle
  final Color backgroundColor;

  const VideoPlayerSubtitlesConfiguration({
    this.fontSize = 14,
    this.fontSizeInFullscreen = 22,
    this.fontColor = Colors.white,
    this.outlineColor = Colors.black,
    this.outlineSize = 3.0,
    this.fontFamily = "Roboto",
    this.leftPadding = 8.0,
    this.rightPadding = 8.0,
    this.bottomPadding = 20.0,
    this.backgroundColor = Colors.transparent,
  });
}
