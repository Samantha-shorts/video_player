import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:video_player/abr/abr_track.dart';
import 'package:video_player/controls/material_video_progress_bar.dart';
import 'package:video_player/subtitles/video_player_subtitles_source.dart';
import 'package:video_player/subtitles/video_player_subtitles_source_type.dart';
import 'package:video_player/utils.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player/video_player_controller_state.dart';
import 'package:video_player/video_player_value.dart';

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
          const _PipButton(),
          _MoreButton(
            controller: controller,
            onTap: () {
              _showMaterialBottomSheet([_buildMoreOptionsList()]);
            },
          ),
        ],
      ),
    );
  }

  void _showMaterialBottomSheet(List<Widget> children) {
    showModalBottomSheet<void>(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: controlsConfiguration.overflowModalColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
              ),
              child: Column(
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreOptionsList() {
    return SingleChildScrollView(
      // ignore: avoid_unnecessary_containers
      child: Container(
        child: Column(
          children: [
            _buildMoreOptionsListRow(
              controlsConfiguration.playbackSpeedIcon,
              "Playback Speed",
              () {
                Navigator.of(context).pop();
                _showSpeedChooserWidget();
              },
            ),
            _buildMoreOptionsListRow(
              controlsConfiguration.subtitlesIcon,
              "Subtitles",
              () {
                Navigator.of(context).pop();
                _showSubtitlesSelectionWidget();
              },
            ),
            _buildMoreOptionsListRow(
              controlsConfiguration.qualitiesIcon,
              "Quality",
              () {
                Navigator.of(context).pop();
                _showQualitiesSelectionWidget();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionsListRow(
      IconData icon, String name, void Function() onTap) {
    return MaterialClickableWidget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              icon,
              color: controlsConfiguration.overflowMenuIconsColor,
            ),
            const SizedBox(width: 16),
            Text(
              name,
              style: _getOverflowMenuElementTextStyle(false),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _getOverflowMenuElementTextStyle(bool isSelected) {
    return TextStyle(
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: isSelected
          ? controlsConfiguration.overflowModalTextColor
          : controlsConfiguration.overflowModalTextColor.withOpacity(0.7),
    );
  }

  void _showSpeedChooserWidget() {
    _showMaterialBottomSheet([
      _buildSpeedRow(0.25),
      _buildSpeedRow(0.5),
      _buildSpeedRow(0.75),
      _buildSpeedRow(1.0),
      _buildSpeedRow(1.25),
      _buildSpeedRow(1.5),
      _buildSpeedRow(1.75),
      _buildSpeedRow(2.0),
    ]);
  }

  Widget _buildSpeedRow(double value) {
    final bool isSelected = lastValue?.playbackRate == value;

    return MaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        controller.setPlaybackRate(value);
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
                )),
            const SizedBox(width: 16),
            Text(
              "$value x",
              style: _getOverflowMenuElementTextStyle(isSelected),
            )
          ],
        ),
      ),
    );
  }

  void _showSubtitlesSelectionWidget() {
    final subtitles = controller.subtitlesController.subtitlesSourceList;
    final noneSubtitlesElementExists = subtitles.firstWhereOrNull(
            (source) => source.type == VideoPlayerSubtitlesSourceType.none) !=
        null;
    if (!noneSubtitlesElementExists) {
      subtitles.add(VideoPlayerSubtitlesSource(
          type: VideoPlayerSubtitlesSourceType.none));
    }

    _showMaterialBottomSheet(
        subtitles.map((source) => _buildSubtitlesSourceRow(source)).toList());
  }

  Widget _buildSubtitlesSourceRow(VideoPlayerSubtitlesSource subtitlesSource) {
    final bool isSelected = subtitlesSource ==
        controller.subtitlesController.selectedSubtitlesSource;

    return MaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        controller.subtitlesController.setSubtitleSource(subtitlesSource);
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
              subtitlesSource.type == VideoPlayerSubtitlesSourceType.none
                  ? "None"
                  : subtitlesSource.name ?? "Default",
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitiesSelectionWidget() {
    final rows = controller.tracksController.abrTracks.map((track) {
      if (track.width == 0 && track.height == 0 && track.bitrate == 0) {
        return _buildTrackRow(track, "Auto");
      } else {
        return _buildTrackRow(track, null);
      }
    }).toList();

    if (rows.isEmpty) {
      rows.add(
        _buildTrackRow(AbrTrack.defaultTrack(), "Auto"),
      );
    }

    _showMaterialBottomSheet(rows);
  }

  Widget _buildTrackRow(AbrTrack track, String? preferredName) {
    final int width = track.width ?? 0;
    final int height = track.height ?? 0;
    final int bitrate = track.bitrate ?? 0;
    final String mimeType = (track.mimeType ?? '').replaceAll('video/', '');
    final String trackName = preferredName ??
        "${width}x$height ${Utils.formatBitrate(bitrate)} $mimeType";

    final selectedTrack = controller.tracksController.selectedTrack;
    final bool isSelected = (selectedTrack != null && selectedTrack == track) ||
        (selectedTrack == null &&
            track.width == 0 &&
            track.height == 0 &&
            track.bitrate == 0);

    return MaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        controller.tracksController.selectTrack(track);
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
                )),
            const SizedBox(width: 16),
            Text(
              trackName,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
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
          Expanded(child: _ReplayButton()),
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
                _PlayPauseButton(),
                Expanded(child: _PositionText()),
                Spacer(),
                _MuteButton(),
                _FullscreenButton(),
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
                colors: controlsConfiguration.progressColors,
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
                  } else {
                    await controller.disablePictureInPicture();
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

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.controller, required this.onTap});

  final VideoPlayerController controller;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    final controlsConfiguration =
        controller.configuration.controlsConfiguration;
    return MaterialClickableWidget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          controlsConfiguration.overflowMenuIcon,
          color: controlsConfiguration.iconsColor,
        ),
      ),
    );
  }
}

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
      onTap: () {
        if (lastValue?.isPlaying == true) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: Icon(
        // TODO: show Icons.replay if finished
        lastValue?.isPlaying == true
            ? controlsConfiguration.pauseIcon
            : controlsConfiguration.playIcon,
        size: 42,
        color: controlsConfiguration.iconsColor,
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.isPlayingChanged;
  }
}

class _PlayPauseButton extends StatefulWidget {
  const _PlayPauseButton({super.key});

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState
    extends VideoPlayerControllerState<_PlayPauseButton> {
  @override
  Widget build(BuildContext context) {
    return MaterialClickableWidget(
      onTap: () {
        if (lastValue?.isPlaying == true) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          lastValue?.isPlaying == true
              ? controlsConfiguration.pauseIcon
              : controlsConfiguration.playIcon,
          color: controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.isPlayingChanged;
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

class _MuteButton extends StatefulWidget {
  const _MuteButton({super.key});

  @override
  State<_MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends VideoPlayerControllerState<_MuteButton> {
  @override
  Widget build(BuildContext context) {
    return MaterialClickableWidget(
      onTap: () {
        if (lastValue?.isMuted == true) {
          controller.setMuted(false);
        } else {
          controller.setMuted(true);
        }
      },
      child: ClipRect(
        child: Container(
          height: controlsConfiguration.controlBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            lastValue?.isMuted != true
                ? controlsConfiguration.muteIcon
                : controlsConfiguration.unMuteIcon,
            color: controlsConfiguration.iconsColor,
          ),
        ),
      ),
    );
  }

  @override
  bool willRebuild(VideoPlayerValue? oldValue, VideoPlayerValue newValue) {
    return newValue.eventType == VideoPlayerEventType.muteChanged;
  }
}

class _FullscreenButton extends StatefulWidget {
  const _FullscreenButton({super.key});

  @override
  State<_FullscreenButton> createState() => _FullscreenButtonState();
}

class _FullscreenButtonState
    extends VideoPlayerControllerState<_FullscreenButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: MaterialClickableWidget(
        onTap: () {
          if (lastValue?.isFullscreen != true) {
            controller.enterFullscreen();
          } else {
            controller.exitFullscreen();
          }
        },
        child: Container(
          height: controlsConfiguration.controlBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Center(
            child: Icon(
              lastValue?.isFullscreen == true
                  ? controlsConfiguration.fullscreenDisableIcon
                  : controlsConfiguration.fullscreenEnableIcon,
              color: controlsConfiguration.iconsColor,
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
    return newValue.eventType == VideoPlayerEventType.fullscreenChanged;
  }
}
