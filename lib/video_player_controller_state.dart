import 'package:flutter/material.dart';
import 'package:video_player/configurations/video_player_controls_configuration.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player/video_player_value.dart';

abstract class VideoPlayerControllerState<T extends StatefulWidget>
    extends State<T> {
  VideoPlayerController? _controller;
  VideoPlayerController get controller => _controller!;

  VideoPlayerControlsConfiguration get controlsConfiguration =>
      controller.configuration.controlsConfiguration;

  VideoPlayerValue? _lastValue;

  VideoPlayerValue? get lastValue => _lastValue;

  Future<void> setup() async {
    controller.addListener(_playerValueListener);
    _lastValue = _controller?.value;
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }

  void clear() {
    _controller?.removeListener(_playerValueListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final oldController = _controller;
    final newController = VideoPlayerController.of(context);
    if (oldController != newController) {
      clear();
      _controller = newController;
      setup();
    }
  }

  void _playerValueListener() {
    final rebuilds = willRebuild(_lastValue, controller.value);
    if (rebuilds) {
      setState(() {
        _lastValue = controller.value;
      });
    } else {
      _lastValue = controller.value;
    }
  }

  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) =>
      false;
}
