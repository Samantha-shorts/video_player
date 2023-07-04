import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:video_player/configurations/configurations.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/subtitles/subtitles.dart';

class VideoPlayerSubtitlesDrawer extends StatefulWidget {
  const VideoPlayerSubtitlesDrawer({Key? key}) : super(key: key);

  @override
  State<VideoPlayerSubtitlesDrawer> createState() =>
      _VideoPlayerSubtitlesDrawerState();
}

class _VideoPlayerSubtitlesDrawerState
    extends VideoPlayerControllerState<VideoPlayerSubtitlesDrawer> {
  final RegExp htmlRegExp = RegExp(r"<[^>]*>", multiLine: true);
  TextStyle? _innerTextStyle;
  TextStyle? _outerTextStyle;

  VideoPlayerSubtitlesConfiguration get subtitlesConfiguration =>
      controller.configuration.subtitlesConfiguration;

  StreamSubscription? _subtitleStreamSubscription;
  StreamSubscription? _controlsVisibilitySubscription;

  bool _isControlsVisible = false;

  @override
  Future<void> setup() async {
    await super.setup();
    _subtitleStreamSubscription = controller.subtitlesController.subtitlesStream
        .listen(_subtitleStreamListener);
    _controlsVisibilitySubscription =
        controller.controlsVisibilityStream.listen(_controlsVisibilityListener);

    _outerTextStyle = TextStyle(
      fontSize: lastValue?.isFullscreen == true
          ? subtitlesConfiguration.fontSizeInFullscreen
          : subtitlesConfiguration.fontSize,
      fontFamily: subtitlesConfiguration.fontFamily,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = subtitlesConfiguration.outlineSize
        ..color = subtitlesConfiguration.outlineColor,
    );

    _innerTextStyle = TextStyle(
      fontSize: lastValue?.isFullscreen == true
          ? subtitlesConfiguration.fontSizeInFullscreen
          : subtitlesConfiguration.fontSize,
      fontFamily: subtitlesConfiguration.fontFamily,
      color: subtitlesConfiguration.fontColor,
    );
  }

  void _subtitleStreamListener(SubtitlesStreamEvent event) async {
    switch (event) {
      case SubtitlesStreamEvent.didReset:
        setState(() {});
        break;
      case SubtitlesStreamEvent.sourceListChanged:
        break;
      case SubtitlesStreamEvent.selectedSourceChanged:
        if (controller.subtitlesController.selectedSubtitlesSource
                    ?.asmsIsSegmented ==
                true &&
            lastValue?.position != null) {
          await controller.subtitlesController
              .loadAsmsSubtitlesSegments(lastValue!.position);
        }
        setState(() {});
        break;
    }
  }

  void _controlsVisibilityListener(bool controlsVisible) {
    setState(() {
      _isControlsVisible = controlsVisible;
    });
  }

  @override
  void clear() {
    super.clear();
    _subtitleStreamSubscription?.cancel();
    _controlsVisibilitySubscription?.cancel();
  }

  @override
  bool willRebuild(
    VideoPlayerValue? oldValue,
    VideoPlayerValue newValue,
  ) {
    if (newValue.eventType == VideoPlayerEventType.positionChanged) {
      if (controller
              .subtitlesController.selectedSubtitlesSource?.asmsIsSegmented ==
          true) {
        controller.subtitlesController
            .loadAsmsSubtitlesSegments(newValue.position);
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerSubtitle? subtitle = _getSubtitleAtCurrentPosition();
    final List<String> subtitles = subtitle?.texts ?? [];
    final List<Widget> textWidgets =
        subtitles.map((text) => _buildSubtitleTextWidget(text)).toList();

    return Container(
      height: double.infinity,
      width: double.infinity,
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: subtitlesConfiguration.bottomPadding +
              (_isControlsVisible ? 30 : 0),
          left: subtitlesConfiguration.leftPadding,
          right: subtitlesConfiguration.rightPadding,
        ),
        duration: Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: textWidgets,
        ),
      ),
    );
  }

  VideoPlayerSubtitle? _getSubtitleAtCurrentPosition() {
    if (lastValue == null) {
      return null;
    }

    final Duration position = lastValue!.position;
    for (final VideoPlayerSubtitle subtitle
        in controller.subtitlesController.subtitlesLines) {
      if (subtitle.start! <= position && subtitle.end! >= position) {
        return subtitle;
      }
    }
    return null;
  }

  Widget _buildSubtitleTextWidget(String subtitleText) {
    return Row(children: [
      Expanded(
        child: Align(
          alignment: Alignment.center,
          child: _getTextWithStroke(subtitleText),
        ),
      ),
    ]);
  }

  Widget _getTextWithStroke(String subtitleText) {
    return Container(
      color: subtitlesConfiguration.backgroundColor,
      child: Stack(
        children: [
          if (_outerTextStyle != null)
            _buildHtmlWidget(subtitleText, _outerTextStyle!),
          if (_innerTextStyle != null)
            _buildHtmlWidget(subtitleText, _innerTextStyle!)
        ],
      ),
    );
  }

  Widget _buildHtmlWidget(String text, TextStyle textStyle) {
    return HtmlWidget(
      text,
      textStyle: textStyle,
    );
  }

  VideoPlayerSubtitlesConfiguration setupDefaultConfiguration() {
    return const VideoPlayerSubtitlesConfiguration();
  }
}
