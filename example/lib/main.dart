import 'package:example/pages/basic_player_page.dart';
import 'package:example/pages/custom_controls_page.dart';
import 'package:example/pages/download_hls_page.dart';
import 'package:example/pages/drm_video_page.dart';
import 'package:example/pages/external_vtt_page.dart';
import 'package:example/pages/no_subtitles_page.dart';
import 'package:example/pages/scroll_video_page.dart';
import 'package:example/pages/srt_subtitle_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'video_player demo',
      home: WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("video_player Example"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          children: [...buildExampleElementWidgets()],
        ),
      ),
    );
  }

  List<Widget> buildExampleElementWidgets() {
    return [
      const SizedBox(height: 8),
      _buildExampleElementWidget("Basic player", () {
        _navigateToPage(const BasicPlayerPage());
      }),
      _buildExampleElementWidget("Drm video player", () {
        _navigateToPage(const DrmVideoPage());
      }),
      _buildExampleElementWidget("Custom Controls", () {
        _navigateToPage(const CustomControlsPage());
      }),
      _buildExampleElementWidget("External VTT", () {
        _navigateToPage(const ExternalVttPage());
      }),
      _buildExampleElementWidget("SRT Subtitles", () {
        _navigateToPage(const SrtSubtitlePage());
      }),
      _buildExampleElementWidget("No Subtitles", () {
        _navigateToPage(const NoSubtitlesPage());
      }),
      _buildExampleElementWidget("Download HLS", () {
        _navigateToPage(const DownloadHlsPage());
      }),
      _buildExampleElementWidget("Scroll Video Page", () {
        _navigateToPage(const ScrollVideoPage());
      }),
    ];
  }

  Widget _buildExampleElementWidget(String name, Function onClicked) {
    return Material(
      child: InkWell(
        onTap: onClicked as void Function()?,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                name,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }

  Future _navigateToPage(Widget routeWidget) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => routeWidget),
    );
  }
}
