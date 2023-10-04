enum ControlsEventType {
  onTapPlay,
  onTapPause,
  onTapReplay,
  onTapMute,
  onTapSkipForward,
  onTapSkipBack,
  onTapMore,
  onTapPlaybackSpeedMenu,
  onTapPlaybackSpeedValue,
  onTapSubtitlesMenu,
  onTapQualityMenu,
  onTapPip,
  onTapFullscreen,
}

class ControlsEvent {
  ControlsEvent({
    required this.eventType,
    this.muteOn,
    this.pipEnabled,
    this.fullscreenEnabled,
    this.speedValue,
  });

  final ControlsEventType eventType;
  final bool? muteOn;
  final bool? pipEnabled;
  final bool? fullscreenEnabled;
  final double? speedValue;

  @override
  String toString() {
    // ignore: no_runtimetype_tostring
    return '$runtimeType('
        'eventType: $eventType, '
        'muteOn: $muteOn, '
        'pipEnabled: $pipEnabled, '
        'fullscreenEnabled: $fullscreenEnabled, '
        'speedValue: $speedValue'
        ')';
  }
}
