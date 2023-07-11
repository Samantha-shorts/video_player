# video_player

Note: Text stroke is not working properly with the Impeller engine on iOS (https://github.com/flutter/flutter/issues/126010). If you want to correctly display subtitles, please set `FLTEnableImpeller` to false in the Info.plist file (https://docs.flutter.dev/perf/impeller#ios).

## Introduction

This plugin is based on [betterplayer](https://github.com/jhomlala/betterplayer). BetterPlayer provides awesome features, such as UI customizability and SRT support. In addition, it's one of the few video players in Flutter plugins implementing Picture in Picture. However it contains bugs, and in order to fix them, a fundamental redesign was necessary. Therefore, while reusing the source code of BetterPlayer, I have re-implemented it with a simpler design.
