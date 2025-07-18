import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/controls/controls.dart';
import 'package:video_player/subtitles/subtitles.dart';

class VideoPlayerWithControls extends StatefulWidget {
  final VideoPlayerController? controller;

  const VideoPlayerWithControls({
    Key? key,
    this.controller,
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
      ],
    );
  }
}

class _Player extends StatefulWidget {
  const _Player({
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

      if (Platform.isAndroid &&
          widget.controller.value.eventType ==
              VideoPlayerEventType.fullscreenChanged) {
        widget.controller.refreshPlayer();
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
    if (_textureId == null) {
      return Container();
    }

    const viewType = "matsune.video_player/VideoPlayerView";
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        creationParamsCodec: const StandardMessageCodec(),
        creationParams: {
          'textureId': _textureId!,
          'isFullscreen': widget.controller.value.isFullscreen
        },
      );
    } else {
      return ValueListenableBuilder(
        valueListenable: widget.controller,
        builder: (context, value, child) {
          final androidViewType = "$viewType$_textureId";
          return PlatformViewLink(
            key: ValueKey(value.playbackStateChangedTimestamp),
            viewType: androidViewType,
            surfaceFactory: (context, controller) {
              return AndroidViewSurface(
                controller: controller as AndroidViewController,
                gestureRecognizers: const <Factory<
                    OneSequenceGestureRecognizer>>{},
                hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              );
            },
            onCreatePlatformView: (params) {
              // NOTE: ここでcontrollerの初期化処理を行う この時textureIdを渡す
              return PlatformViewsService.initSurfaceAndroidView(
                id: params.id,
                viewType: androidViewType,
                layoutDirection: TextDirection.ltr,
                creationParamsCodec: const StandardMessageCodec(),
              )
                ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
                ..create();
            },
          );
        },
      );
    }
  }
}
