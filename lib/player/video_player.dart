import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/configurations/configurations.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/fullscreen/fullscreen_video_page.dart';
import 'package:video_player/player/player.dart';

///Widget which uses provided controller to render video player.
class VideoPlayer extends StatefulWidget {
  const VideoPlayer({
    Key? key,
    required this.controller,
    this.noProvider = false,
  }) : super(key: key);

  final VideoPlayerController controller;
  final bool noProvider;

  @override
  State<VideoPlayer> createState() {
    return _VideoPlayerState();
  }

  factory VideoPlayer.network(
    String fileUrl, {
    VideoPlayerConfiguration? configuration,
  }) =>
      VideoPlayer(
        controller: VideoPlayerController(
          configuration: configuration ?? VideoPlayerConfiguration(),
          dataSource: VideoPlayerDataSource(
            sourceType: VideoPlayerDataSourceType.network,
            fileUrl: fileUrl,
          ),
        ),
      );

  factory VideoPlayer.offline(
    String offlineKey, {
    VideoPlayerConfiguration? configuration,
  }) =>
      VideoPlayer(
        controller: VideoPlayerController(
          configuration: configuration ?? VideoPlayerConfiguration(),
          dataSource: VideoPlayerDataSource(
            sourceType: VideoPlayerDataSourceType.offline,
            offlineKey: offlineKey,
          ),
        ),
      );
}

class _VideoPlayerState extends State<VideoPlayer> {
  ///State of navigator on widget created
  late NavigatorState _navigatorState;

  bool _initialized = false;

  bool _isFullscreen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final navigator = Navigator.of(context);
      setState(() {
        _navigatorState = navigator;
      });
      _setup();
      _initialized = true;
    }
  }

  Future<void> _setup() async {
    widget.controller.addListener(_controllerListener);
  }

  @override
  void dispose() {
    if (_isFullscreen) {
      _navigatorState.maybePop();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays:
              widget.controller.configuration.systemOverlaysAfterFullScreen);
      SystemChrome.setPreferredOrientations(
          widget.controller.configuration.deviceOrientationsAfterFullScreen);
    }

    widget.controller.removeListener(_controllerListener);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayer oldWidget) {
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerListener);
      widget.controller.addListener(_controllerListener);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _controllerListener() async {
    if (widget.controller.value.eventType ==
        VideoPlayerEventType.fullscreenChanged) {
      // detect controller fullscreen state has changed
      _isFullscreen = widget.controller.value.isFullscreen;
      if (widget.controller.value.isFullscreen) {
        await enterFullscreen();
      } else {
        await exitFullscreen();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.noProvider
        ? _buildPlayer()
        : VideoPlayerControllerProvider(
            controller: widget.controller,
            child: _buildPlayer(),
          );
  }

  Future<void> exitFullscreen() async {
    Navigator.of(context, rootNavigator: true).pop();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays:
            widget.controller.configuration.systemOverlaysAfterFullScreen);
    await SystemChrome.setPreferredOrientations(
        widget.controller.configuration.deviceOrientationsAfterFullScreen);
  }

  Future<void> enterFullscreen() async {
    await _pushFullScreenWidget(context);
  }

  Future<dynamic> _pushFullScreenWidget(BuildContext context) async {
    final TransitionRoute<void> route = PageRouteBuilder<void>(
      settings: const RouteSettings(),
      pageBuilder: _fullScreenRoutePageBuilder,
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(
      widget.controller.configuration.deviceOrientationsOnFullScreen,
    );

    if (context.mounted) Navigator.of(context, rootNavigator: true).push(route);
  }

  AnimatedWidget _defaultRoutePageBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return VideoPlayerControllerProvider(
          controller: widget.controller,
          child: const FullscreenVideoPage(),
        );
      },
    );
  }

  Widget _fullScreenRoutePageBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _defaultRoutePageBuilder(
      context,
      animation,
      secondaryAnimation,
    );
  }

  Widget _buildPlayer() {
    return VideoPlayerWithControls(
      controller: widget.controller,
    );
  }
}
