import 'package:flutter/material.dart';
import 'package:video_player/controls/progress_colors.dart';

class VideoPlayerControlsConfiguration {
  ///Color of the control bars
  final Color controlBarColor;

  ///Color of texts
  final Color textColor;

  ///Color of icons
  final Color iconsColor;

  ///Icon of play
  final IconData playIcon;

  ///Icon of pause
  final IconData pauseIcon;

  ///Icon of mute
  final IconData muteIcon;

  ///Icon of unmute
  final IconData unMuteIcon;

  ///Icon of fullscreen mode enable
  final IconData fullscreenEnableIcon;

  ///Icon of fullscreen mode disable
  final IconData fullscreenDisableIcon;

  ///Cupertino only icon, icon of skip
  final IconData skipBackIcon;

  ///Cupertino only icon, icon of forward
  final IconData skipForwardIcon;

  ///Progress bar played color
  final Color progressBarPlayedColor;

  ///Progress bar circle color
  final Color progressBarHandleColor;

  ///Progress bar buffered video color
  final Color progressBarBufferedColor;

  ///Progress bar background color
  final Color progressBarBackgroundColor;

  ///Time to hide controls
  final Duration controlsHideTime;

  ///Control bar height
  final double controlBarHeight;

  ///Icon of the overflow menu
  final IconData overflowMenuIcon;

  ///Icon of the PiP menu
  final IconData pipMenuIcon;

  ///Icon of the expand menu
  final IconData expandIcon;

  ///Icon of the shrink menu
  final IconData shrinkIcon;

  ///Icon of the playback speed menu item from overflow menu
  final IconData playbackSpeedIcon;

  ///Icon of the subtitles menu item from overflow menu
  final IconData subtitlesIcon;

  ///Icon of the qualities menu item from overflow menu
  final IconData qualitiesIcon;

  // ///Icon of the audios menu item from overflow menu
  // final IconData audioTracksIcon;

  ///Color of overflow menu icons
  final Color overflowMenuIconsColor;

  ///Time which will be used once user uses forward
  final int forwardSkipTimeInMilliseconds;

  ///Time which will be used once user uses backward
  final int backwardSkipTimeInMilliseconds;

  ///Color of default loading indicator
  final Color loadingColor;

  // ///Widget which can be used instead of default progress
  // final Widget? loadingWidget;

  ///Color of the background, when no frame is displayed.
  final Color backgroundColor;

  ///Color of the bottom modal sheet used for overflow menu items.
  final Color overflowModalColor;

  ///Color of text in bottom modal sheet used for overflow menu items.
  final Color overflowModalTextColor;

  final bool disableSeek;

  const VideoPlayerControlsConfiguration({
    this.controlBarColor = Colors.black26,
    this.textColor = Colors.white,
    this.iconsColor = Colors.white,
    this.playIcon = Icons.play_arrow_outlined,
    this.pauseIcon = Icons.pause_outlined,
    this.muteIcon = Icons.volume_up_outlined,
    this.unMuteIcon = Icons.volume_off_outlined,
    this.fullscreenEnableIcon = Icons.fullscreen_outlined,
    this.fullscreenDisableIcon = Icons.fullscreen_exit_outlined,
    this.skipBackIcon = Icons.replay_10_outlined,
    this.skipForwardIcon = Icons.forward_10_outlined,
    this.progressBarPlayedColor = Colors.white,
    this.progressBarHandleColor = Colors.white,
    this.progressBarBufferedColor = Colors.white70,
    this.progressBarBackgroundColor = Colors.white60,
    this.controlsHideTime = const Duration(milliseconds: 300),
    this.controlBarHeight = 48.0,
    this.overflowMenuIcon = Icons.more_vert_outlined,
    this.pipMenuIcon = Icons.picture_in_picture_outlined,
    this.expandIcon = Icons.open_in_full_outlined,
    this.shrinkIcon = Icons.close_fullscreen_outlined,
    this.playbackSpeedIcon = Icons.shutter_speed_outlined,
    this.qualitiesIcon = Icons.hd_outlined,
    this.subtitlesIcon = Icons.closed_caption_outlined,
    this.overflowMenuIconsColor = Colors.black,
    this.forwardSkipTimeInMilliseconds = 10000,
    this.backwardSkipTimeInMilliseconds = 10000,
    this.loadingColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.overflowModalColor = Colors.white,
    this.overflowModalTextColor = Colors.black,
    this.disableSeek = false,
  });

  ProgressColors get progressColors => ProgressColors(
        playedColor: progressBarPlayedColor,
        handleColor: progressBarHandleColor,
        bufferedColor: progressBarBufferedColor,
        backgroundColor: progressBarBackgroundColor,
      );
}
