class VideoPlayerNotificationConfiguration {
  ///Title of the given data source, used in controls notification
  final String? title;

  ///Author of the given data source, used in controls notification
  final String? author;

  ///Image of the video, used in controls notification
  final String? imageUrl;

  ///Name of the notification channel. Used only in Android.
  final String? notificationChannelName;

  ///Name of activity used to open application from notification. Used only
  ///in Android.
  final String? activityName;

  const VideoPlayerNotificationConfiguration({
    this.title,
    this.author,
    this.imageUrl,
    this.notificationChannelName,
    this.activityName,
  });
}
