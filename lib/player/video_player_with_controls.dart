import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/controls/controls.dart';
import 'package:video_player/platform/platform.dart';
import 'package:video_player/subtitles/subtitles.dart';

class VideoPlayerWithControls extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool isLoading;

  const VideoPlayerWithControls({
    Key? key,
    this.controller,
    required this.isLoading,
  }) : super(key: key);

  @override
  VideoPlayerWithControlsState createState() => VideoPlayerWithControlsState();
}

class VideoPlayerWithControlsState extends State<VideoPlayerWithControls> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final videoPlayerController = VideoPlayerController.of(context);

    final aspectRatio =
        videoPlayerController.configuration.aspectRatio ?? 16 / 9;
    return Container(
      width: double.infinity,
      color: videoPlayerController
          .configuration.controlsConfiguration.backgroundColor,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _buildPlayerWithControls(videoPlayerController, context),
      ),
    );
  }

  Widget _buildPlayerWithControls(
    VideoPlayerController videoPlayerController,
    BuildContext context,
  ) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        _Player(controller: videoPlayerController),
        const VideoPlayerSubtitlesDrawer(),
        if (widget.controller?.configuration.hidesControls != true)
          const MaterialControls(),
        if (widget.isLoading)
          const IgnorePointer(child: Center(child: CircularProgressIndicator()))
      ],
    );
  }
}

class _Player extends StatefulWidget {
  const _Player({
    super.key,
    required this.controller,
  });

  final VideoPlayerController controller;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  late VoidCallback _listener;
  int? _textureId;

  _PlayerState() {
    _listener = () {
      final int? newTextureId = widget.controller.textureId;
      if (newTextureId != _textureId) {
        setState(() {
          _textureId = newTextureId;
        });
      }
    };
  }

  @override
  void initState() {
    super.initState();
    _textureId = widget.controller.textureId;
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(covariant _Player oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_listener);
    _textureId = widget.controller.textureId;
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _textureId == null
        ? Container()
        : VideoPlayerPlatform.instance.buildView(
            _textureId!,
            widget.controller.value.isFullscreen,
          );
  }
}
