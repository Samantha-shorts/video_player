import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:video_player/platform/platform.dart';
import 'package:video_player/video_player.dart';

// TODO: 環境変数や関数の変数経由で渡すようにすること
const _fairplayCertUrl =
    'https://9ab821txf9.execute-api.ap-northeast-1.amazonaws.com/license/fps-cert';
const _fairplayLicenseUrl =
    'https://9ab821txf9.execute-api.ap-northeast-1.amazonaws.com/license/fairplay';
const _widevineLicenseUrl =
    'https://9ab821txf9.execute-api.ap-northeast-1.amazonaws.com/license/widevine';

const _drmHlsFileUrl =
    'https://d1qg19f7rqukzl.cloudfront.net/big_buck_bunny_dev_20240917/HLS/big_buck_bunny_1080p_h264.m3u8';
const _drmDashFileUrl =
    'https://d1qg19f7rqukzl.cloudfront.net/big_buck_bunny_dev_20240823/DASH/big_buck_bunny_1080p_h264.mpd';

class DrmVideoPage extends StatefulWidget {
  const DrmVideoPage({super.key});
  @override
  State<DrmVideoPage> createState() => _DrmVideoPageState();
}

class _DrmVideoPageState extends State<DrmVideoPage> {
  final controller = VideoPlayerController(
    configuration: VideoPlayerConfiguration(
      autoPlay: false,
      autoLoop: true,
    ),
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
      appBar: AppBar(
        title: const Text("Drm video"),
      ),
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
