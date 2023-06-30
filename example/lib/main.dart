import 'package:flutter/material.dart';
import 'package:video_player_example/pages/basic_player_page.dart';

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
    // _saveAssetSubtitleToFile();
    // _saveAssetVideoToFile();
    // _saveAssetEncryptVideoToFile();
    // _saveLogoToFile();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("video_player Example"),
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
        _navigateToPage(BasicPlayerPage());
      }),
      //     _buildExampleElementWidget("Normal player", () {
      //       _navigateToPage(NormalPlayerPage());
      //     }),
      //     _buildExampleElementWidget("Controls configuration", () {
      //       _navigateToPage(ControlsConfigurationPage());
      //     }),
      //     _buildExampleElementWidget("Event listener", () {
      //       _navigateToPage(EventListenerPage());
      //     }),
      //     _buildExampleElementWidget("Subtitles", () {
      //       _navigateToPage(SubtitlesPage());
      //     }),
      //     _buildExampleElementWidget("Resolutions", () {
      //       _navigateToPage(ResolutionsPage());
      //     }),
      //     _buildExampleElementWidget("HLS subtitles", () {
      //       _navigateToPage(HlsSubtitlesPage());
      //     }),
      //     _buildExampleElementWidget("HLS tracks", () {
      //       _navigateToPage(HlsTracksPage());
      //     }),
      //     _buildExampleElementWidget("HLS Audio", () {
      //       _navigateToPage(HlsAudioPage());
      //     }),
      //     _buildExampleElementWidget("Cache", () {
      //       _navigateToPage(CachePage());
      //     }),
      //     _buildExampleElementWidget("Playlist", () {
      //       _navigateToPage(PlaylistPage());
      //     }),
      //     _buildExampleElementWidget("Video in list", () {
      //       _navigateToPage(VideoListPage());
      //     }),
      //     _buildExampleElementWidget("Rotation and fit", () {
      //       _navigateToPage(RotationAndFitPage());
      //     }),
      //     _buildExampleElementWidget("Memory player", () {
      //       _navigateToPage(MemoryPlayerPage());
      //     }),
      //     _buildExampleElementWidget("Controller controls", () {
      //       _navigateToPage(ControllerControlsPage());
      //     }),
      //     _buildExampleElementWidget("Auto fullscreen orientation", () {
      //       _navigateToPage(AutoFullscreenOrientationPage());
      //     }),
      //     _buildExampleElementWidget("Overridden aspect ratio", () {
      //       _navigateToPage(OverriddenAspectRatioPage());
      //     }),
      //     _buildExampleElementWidget("Notifications player", () {
      //       _navigateToPage(NotificationPlayerPage());
      //     }),
      //     _buildExampleElementWidget("Reusable video list", () {
      //       _navigateToPage(ReusableVideoListPage());
      //     }),
      //     _buildExampleElementWidget("Fade placeholder", () {
      //       _navigateToPage(FadePlaceholderPage());
      //     }),
      //     _buildExampleElementWidget("Placeholder until play", () {
      //       _navigateToPage(PlaceholderUntilPlayPage());
      //     }),
      //     _buildExampleElementWidget("Change player theme", () {
      //       _navigateToPage(ChangePlayerThemePage());
      //     }),
      //     _buildExampleElementWidget("Overridden duration", () {
      //       _navigateToPage(OverriddenDurationPage());
      //     }),
      //     _buildExampleElementWidget("Picture in Picture", () {
      //       _navigateToPage(PictureInPicturePage());
      //     }),
      //     _buildExampleElementWidget("Controls always visible", () {
      //       _navigateToPage(ControlsAlwaysVisiblePage());
      //     }),
      //     _buildExampleElementWidget("DRM", () {
      //       _navigateToPage(DrmPage());
      //     }),
      //     _buildExampleElementWidget("ClearKey DRM", () {
      //       _navigateToPage(ClearKeyPage());
      //     }),
      //     _buildExampleElementWidget("DASH", () {
      //       _navigateToPage(DashPage());
      //     }),
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
                style: TextStyle(fontSize: 16),
              ),
            ),
            Divider(),
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

  // ///Save subtitles to file, so we can use it later
  // Future _saveAssetSubtitleToFile() async {
  //   String content =
  //       await rootBundle.loadString("assets/example_subtitles.srt");
  //   final directory = await getApplicationDocumentsDirectory();
  //   var file = File("${directory.path}/example_subtitles.srt");
  //   file.writeAsString(content);
  // }

  // ///Save video to file, so we can use it later
  // Future _saveAssetVideoToFile() async {
  //   var content = await rootBundle.load("assets/testvideo.mp4");
  //   final directory = await getApplicationDocumentsDirectory();
  //   var file = File("${directory.path}/testvideo.mp4");
  //   file.writeAsBytesSync(content.buffer.asUint8List());
  // }

  // Future _saveAssetEncryptVideoToFile() async {
  //   var content =
  //       await rootBundle.load("assets/${Constants.fileTestVideoEncryptUrl}");
  //   final directory = await getApplicationDocumentsDirectory();
  //   var file = File("${directory.path}/${Constants.fileTestVideoEncryptUrl}");
  //   file.writeAsBytesSync(content.buffer.asUint8List());
  // }

  // ///Save logo to file, so we can use it later
  // Future _saveLogoToFile() async {
  //   var content = await rootBundle.load("assets/${Constants.logo}");
  //   final directory = await getApplicationDocumentsDirectory();
  //   var file = File("${directory.path}/${Constants.logo}");
  //   file.writeAsBytesSync(content.buffer.asUint8List());
  // }
}

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   @override
//   Widget build(BuildContext context) {
//     final controller = VideoPlayerController(
//       configuration: const VideoPlayerConfiguration(
//         aspectRatio: 16 / 9,
//         autoPlay: true,
//       ),
//     );
//     controller.setNetworkDataSource(
//       "https://d173fw6w6ru1im.cloudfront.net/converted/20/00be8f6d9f2f95a6b7cd7102f0f64382.m3u8",
//       // "https://mtoczko.github.io/hls-test-streams/test-group/playlist.m3u8",
//     );
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(
//           title: const Text('Plugin example app'),
//         ),
//         body: SingleChildScrollView(
//           child: Column(
//             children: [
//               VideoPlayer(controller: controller),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
