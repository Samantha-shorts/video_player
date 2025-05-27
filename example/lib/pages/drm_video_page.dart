import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const _drmHlsFileUrl =
    'https://d1qg19f7rqukzl.cloudfront.net/big_buck_bunny_dev_20240917/HLS/big_buck_bunny_1080p_h264.m3u8';
const _drmDashFileUrl =
    'https://d1qg19f7rqukzl.cloudfront.net/big_buck_bunny_dev_20240823/DASH/big_buck_bunny_1080p_h264.mpd';

// const _drmHlsFileUrl =
//     'https://d173fw6w6ru1im.cloudfront.net/converted/735/drm/HLS/8ea271709e67344fcb9b1a085d04226d.m3u8';
// const _drmDashFileUrl =
//     'https://d173fw6w6ru1im.cloudfront.net/converted/735/drm/DASH/8ea271709e67344fcb9b1a085d04226d.mpd';

class DrmVideoPage extends StatefulWidget {
  const DrmVideoPage({super.key});
  @override
  State<DrmVideoPage> createState() => _DrmVideoPageState();
}

class _DrmVideoPageState extends State<DrmVideoPage> {
  final controller = VideoPlayerController(
    configuration: VideoPlayerConfiguration(autoPlay: false, autoLoop: true),
  );

  StreamSubscription? _controlsEventSubscription;

  @override
  void initState() {
    super.initState();
    controller.setNetworkDataSource(
      fileUrl: _drmHlsFileUrl,
      drmHlsFileUrl: _drmHlsFileUrl,
      drmDashFileUrl: _drmDashFileUrl,
    );
    _controlsEventSubscription = controller.controlsEventStream.listen((event) {
      debugPrint(event.toString());
    });
  }

  @override
  void dispose() {
    _controlsEventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Drm video")),
      body: Column(
        children: [
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayer(controller: controller),
          ),
        ],
      ),
    );
  }
}
