import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class Utils {
  Utils._();

  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  static log(String message) {
    if (!kReleaseMode) {
      final timestamp = DateTime.now().toString();
      print("[$timestamp] $message");
    }
  }

  static String formatBitrate(int bitrate) {
    if (bitrate < 1000) {
      return "$bitrate bit/s";
    }
    if (bitrate < 1000000) {
      final kbit = (bitrate / 1000).floor();
      return "~$kbit KBit/s";
    }
    final mbit = (bitrate / 1000000).floor();
    return "~$mbit MBit/s";
  }

  static String formatDuration(Duration position) {
    final ms = position.inMilliseconds;

    int seconds = ms ~/ 1000;
    final int hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    final minutes = seconds ~/ 60;
    seconds = seconds % 60;

    final hoursString = hours >= 10
        ? '$hours'
        : hours == 0
            ? '00'
            : '0$hours';

    final minutesString = minutes >= 10
        ? '$minutes'
        : minutes == 0
            ? '00'
            : '0$minutes';

    final secondsString = seconds >= 10
        ? '$seconds'
        : seconds == 0
            ? '00'
            : '0$seconds';

    final formattedTime =
        '${hoursString == '00' ? '' : '$hoursString:'}$minutesString:$secondsString';

    return formattedTime;
  }

  static bool isDataSourceHls(String? url) => url?.endsWith("m3u8") == true;

  static Future<String?> getDataFromUrl(
    String url, [
    Map<String, String?>? headers,
  ]) async {
    try {
      final request = await _httpClient.getUrl(Uri.parse(url));
      if (headers != null) {
        headers.forEach((name, value) => request.headers.add(name, value!));
      }

      final response = await request.close();
      var data = "";
      await response.transform(const Utf8Decoder()).listen((content) {
        data += content.toString();
      }).asFuture<String?>();

      return data;
    } catch (exception) {
      Utils.log("GetDataFromUrl failed: $exception");
      return null;
    }
  }

  static bool checkBitPositionIsSet(int number, int bitPosition) {
    if ((number & (1 << (bitPosition - 1))) > 0) {
      return true;
    } else {
      return false;
    }
  }
}
