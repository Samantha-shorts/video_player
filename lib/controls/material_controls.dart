import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/controller/controller.dart';
import 'package:video_player/controls/controls.dart';
import 'package:video_player/utils.dart';
import 'package:video_player/controls/expand_shrink_button.dart';

class MaterialControls extends StatefulWidget {
  const MaterialControls({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MaterialControlsState();
}

class _MaterialControlsState
    extends VideoPlayerControllerState<MaterialControls> {
  final marginSize = 5.0;
  final buttonPadding = 10.0;

  Timer? _hideTimer;
  bool _controlsHidden = false;

  double get controlsOpacity => _controlsHidden ? 0.0 : 1.0;

  @override
  Future<void> setup() async {
    await super.setup();
    if (lastValue?.isPip == true) {
      setControlsHidden(true);
    }
  }

  @override
  void clear() {
    _hideTimer?.cancel();
    super.clear();
  }

  void onTapHitArea() {
    if (lastValue?.isPip == true) return;

    if (lastValue?.isPlaying == true) {
      if (_controlsHidden) {
        // playing & hiding controls => show controls with timer
        _showControlsWithTimer();
      } else {
        // playing & showing controls => hide controls
        _hideControls();
      }
    } else {
      if (_controlsHidden) {
        // pausing & hiding controls => show controls no-timer
        _showControls();
      } else {
        // pausing & showing controls => hide controls
        _hideControls();
      }
    }
  }

  void setControlsHidden(bool hidden) {
    setState(() {
      _controlsHidden = hidden;
      controller.controlsVisibilityStreamController.add(!hidden);
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      setControlsHidden(true);
    });
  }

  /// Show controls and then hide after timeout
  void _showControlsWithTimer() {
    _showControls();
    _startHideTimer();
  }

  void _showControls() {
    _hideTimer?.cancel();
    setControlsHidden(false);
  }

  void _hideControls() {
    _hideTimer?.cancel();
    setControlsHidden(true);
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    if (newValue.eventType == VideoPlayerEventType.initialized) {
      return true;
    }

    if (newValue.eventType == VideoPlayerEventType.isPlayingChanged) {
      if (newValue.isPlaying) {
        _hideControls();
      } else {
        _showControls();
      }
      return false;
    }
    if (newValue.eventType == VideoPlayerEventType.pipChanged) {
      final becamePip = newValue.isPip;
      if (becamePip) {
        // hide controls in PiP
        _hideControls();
      } else {
        // show controls when back from PiP
        if (newValue.isPlaying) {
          _showControlsWithTimer();
        } else {
          _hideControls();
        }
      }
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapHitArea,
      child: AbsorbPointer(
        absorbing: _controlsHidden,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildControlsLayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsLayer() {
    final controls = Stack(
      fit: StackFit.expand,
      children: lastValue?.initialized == true
          ? [
              _buildMiddleRow(),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(),
              ),
            ]
          : [
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    controlsConfiguration.loadingColor,
                  ),
                ),
              ),
            ],
    );
    return AnimatedOpacity(
      opacity: controlsOpacity,
      duration: controlsConfiguration.controlsHideTime,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(color: controlsConfiguration.controlBarColor),
          ),
          lastValue?.isFullscreen == true
              ? SafeArea(child: controls)
              : controls,
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: controlsConfiguration.controlBarHeight,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (lastValue?.isFullscreen == true) const ExpandShrinkButton(),
          const _PipButton(),
          const MoreButton(),
        ],
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Container(
      color: Colors.transparent,
      width: double.infinity,
      height: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _SkipBackButton(
              onClicked: () {
                if (lastValue?.isPlaying == true) {
                  _showControlsWithTimer();
                }
              },
            ),
          ),
          const Expanded(child: _ReplayButton()),
          Expanded(
            child: _SkipForwardButton(
              onClicked: () {
                if (lastValue?.isPlaying == true) {
                  _showControlsWithTimer();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SizedBox(
      height: controlsConfiguration.controlBarHeight + 20.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          const Expanded(
            flex: 75,
            child: Row(
              children: [
                PlayPauseButton(),
                Expanded(child: _PositionText()),
                Spacer(),
                MuteButton(),
                FullscreenButton(),
                SizedBox(),
              ],
            ),
          ),
          Expanded(
            flex: 40,
            child: Container(
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: MaterialVideoProgressBar(
                dragStart: didStartProgressBarDrag,
                dragEnd: didEndProgressBarDrag,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void didStartProgressBarDrag() {
    _showControls();
  }

  void didEndProgressBarDrag() {
    if (lastValue?.isPlaying == true) {
      _showControlsWithTimer();
    } else {
      _showControls();
    }
  }
}

class MaterialClickableWidget extends StatelessWidget {
  final Widget child;
  final void Function() onTap;

  const MaterialClickableWidget({
    Key? key,
    required this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(60),
      ),
      clipBehavior: Clip.hardEdge,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class HitAreaClickableButton extends StatelessWidget {
  const HitAreaClickableButton({
    super.key,
    required this.onClicked,
    required this.icon,
  });
  final VoidCallback onClicked;
  final Widget icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
      child: MaterialClickableWidget(
        onTap: onClicked,
        child: Align(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [icon],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PipButton extends StatefulWidget {
  const _PipButton({super.key});

  @override
  State<_PipButton> createState() => _PipButtonState();
}

class _PipButtonState extends VideoPlayerControllerState<_PipButton> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: controller.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final isPipSupported = snapshot.data ?? false;
        if (!isPipSupported) return const SizedBox();

        return SizedBox(
          height: controlsConfiguration.controlBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MaterialClickableWidget(
                onTap: () async {
                  if (lastValue?.isPip != true) {
                    await controller.enablePictureInPicture();
                    controller.controlsEventStreamController.add(ControlsEvent(
                      eventType: ControlsEventType.onTapPip,
                      pipEnabled: true,
                    ));
                  } else {
                    await controller.disablePictureInPicture();
                    controller.controlsEventStreamController.add(ControlsEvent(
                      eventType: ControlsEventType.onTapPip,
                      pipEnabled: false,
                    ));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    controlsConfiguration.pipMenuIcon,
                    color: controlsConfiguration.iconsColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.pipChanged;
  }
}

// class _MoreButton extends StatelessWidget {
//   const _MoreButton({required this.controller, required this.onTap});

//   final VideoPlayerController controller;

//   final void Function() onTap;

//   @override
//   Widget build(BuildContext context) {
//     final controlsConfiguration =
//         controller.configuration.controlsConfiguration;
//     return MaterialClickableWidget(
//       onTap: () {
//         onTap();
//         controller.controlsEventStreamController
//             .add(ControlsEvent(eventType: ControlsEventType.onTapMore));
//       },
//       child: Padding(
//         padding: const EdgeInsets.all(8),
//         child: Icon(
//           controlsConfiguration.overflowMenuIcon,
//           color: controlsConfiguration.iconsColor,
//         ),
//       ),
//     );
//   }
// }

class _SkipBackButton extends StatefulWidget {
  const _SkipBackButton({
    super.key,
    required this.onClicked,
  });

  final VoidCallback onClicked;

  @override
  State<_SkipBackButton> createState() => _SkipBackButtonState();
}

class _SkipBackButtonState extends VideoPlayerControllerState<_SkipBackButton> {
  @override
  Widget build(BuildContext context) {
    final controlsConfiguration =
        controller.configuration.controlsConfiguration;
    return HitAreaClickableButton(
      onClicked: () {
        final beginning = const Duration().inMilliseconds;
        final skip = (controller.value.position -
                Duration(
                    milliseconds:
                        controlsConfiguration.backwardSkipTimeInMilliseconds))
            .inMilliseconds;
        controller.seekTo(Duration(milliseconds: max(skip, beginning)));
        widget.onClicked();
        controller.controlsEventStreamController
            .add(ControlsEvent(eventType: ControlsEventType.onTapSkipBack));
      },
      icon: Icon(
        controlsConfiguration.skipBackIcon,
        size: 24,
        color: controlsConfiguration.iconsColor,
      ),
    );
  }
}

class _SkipForwardButton extends StatefulWidget {
  const _SkipForwardButton({
    super.key,
    required this.onClicked,
  });

  final VoidCallback onClicked;

  @override
  State<_SkipForwardButton> createState() => _SkipForwardButtonState();
}

class _SkipForwardButtonState
    extends VideoPlayerControllerState<_SkipForwardButton> {
  @override
  Widget build(BuildContext context) {
    return HitAreaClickableButton(
      onClicked: () {
        final end = controller.value.duration!.inMilliseconds;
        final skip = (controller.value.position +
                Duration(
                  milliseconds:
                      controlsConfiguration.forwardSkipTimeInMilliseconds,
                ))
            .inMilliseconds;
        controller.seekTo(Duration(milliseconds: min(skip, end)));
        widget.onClicked();
        controller.controlsEventStreamController
            .add(ControlsEvent(eventType: ControlsEventType.onTapSkipForward));
      },
      icon: Icon(
        controlsConfiguration.skipForwardIcon,
        size: 24,
        color: controlsConfiguration.iconsColor,
      ),
    );
  }
}

class _ReplayButton extends StatefulWidget {
  const _ReplayButton({super.key});

  @override
  State<_ReplayButton> createState() => _ReplayButtonState();
}

class _ReplayButtonState extends VideoPlayerControllerState<_ReplayButton> {
  @override
  Widget build(BuildContext context) {
    return MaterialClickableWidget(
      onTap: () async {
        if (lastValue?.isPlaying == true) {
          controller.pause();
          controller.controlsEventStreamController
              .add(ControlsEvent(eventType: ControlsEventType.onTapPause));
        } else if (lastValue?.isFinished == true) {
          await controller.seekTo(Duration.zero);
          controller.play();
          controller.controlsEventStreamController
              .add(ControlsEvent(eventType: ControlsEventType.onTapReplay));
        } else {
          controller.play();
          controller.controlsEventStreamController
              .add(ControlsEvent(eventType: ControlsEventType.onTapPlay));
        }
      },
      child: Icon(
        lastValue?.isPlaying == true
            ? controlsConfiguration.pauseIcon
            : lastValue?.isFinished == true
                ? Icons.replay
                : controlsConfiguration.playIcon,
        size: 42,
        color: controlsConfiguration.iconsColor,
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.isPlayingChanged ||
        newValue.eventType == VideoPlayerEventType.ended;
  }
}

class _PositionText extends StatefulWidget {
  const _PositionText({super.key});

  @override
  State<_PositionText> createState() => _PositionTextState();
}

class _PositionTextState extends VideoPlayerControllerState<_PositionText> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: RichText(
        text: TextSpan(
            text: Utils.formatDuration(lastValue?.position ?? Duration.zero),
            style: TextStyle(
              fontSize: 10.0,
              color: controlsConfiguration.textColor,
              decoration: TextDecoration.none,
            ),
            children: <TextSpan>[
              TextSpan(
                text:
                    ' / ${Utils.formatDuration(lastValue?.duration ?? Duration.zero)}',
                style: TextStyle(
                  fontSize: 10.0,
                  color: controlsConfiguration.textColor,
                  decoration: TextDecoration.none,
                ),
              )
            ]),
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.initialized ||
        newValue.eventType == VideoPlayerEventType.positionChanged;
  }
}
