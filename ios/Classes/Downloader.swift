//
//  Downloader.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/07/26.
//

import AVKit
import Flutter

class Downloader: NSObject {

    let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private let configuration: URLSessionConfiguration
    private var downloadSession: AVAssetDownloadURLSession!

    init(
        binaryMessanger: FlutterBinaryMessenger,
        sessionIdentifier: String = "video_player_downloader"
    ) {
        eventChannel = FlutterEventChannel(
            name: "video_player_channel/downloadEvents",
            binaryMessenger: binaryMessanger
        )
        configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        super.init()
        downloadSession = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )

        eventChannel.setStreamHandler(self)
    }

    deinit {
        eventChannel.setStreamHandler(nil)
    }

    func startDownload(url: URL, headers: [String: String]?) {
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers ?? [:]])
        let assetTitle = url.lastPathComponent
        let downloadTask = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: assetTitle,
            assetArtworkData: nil,
            options: nil
        )
        downloadTask?.resume()
    }

    //    func getAllDownloadTasks(_ completion: @escaping ([AVAssetDownloadTask]) -> Void) {
    //        downloadSession.getAllTasks { tasks in
    //            completion(tasks.compactMap { $0 as? AVAssetDownloadTask })
    //        }
    //    }
    //
    //    func getDownloadTask(url: URL, _ completion: @escaping (AVAssetDownloadTask?) -> Void) {
    //        getAllDownloadTasks { tasks in
    //            completion(tasks.first(where: { $0.urlAsset.url == url }))
    //        }
    //    }

    /// url is a requested http url, **not a path to local file**.
    func deleteOfflineAsset(url: URL) {
        guard let assetURL = DownloadPathManager.remove(url: url.absoluteString) else {
            return
        }
        do {
            if FileManager.default.fileExists(atPath: assetURL.path) {
                try FileManager.default.removeItem(at: assetURL)
            }
        } catch {
            sendEvent(.error, ["error": error.localizedDescription as Any])
        }
    }
}

extension Downloader: AVAssetDownloadDelegate {
    func urlSession(
        _ session: URLSession, assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        var percentComplete = 0.0
        // Iterate through the loaded time ranges
        for value in loadedTimeRanges {
            // Unwrap the CMTimeRange from the NSValue
            let loadedTimeRange = value.timeRangeValue
            // Calculate the percentage of the total expected asset duration
            percentComplete +=
                loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        sendEvent(
            .progress,
            [
                "url": assetDownloadTask.urlAsset.url.absoluteString,
                "progress": percentComplete,
            ])
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        if let error = error {
            sendEvent(
                .error,
                [
                    "url": (task as? AVAssetDownloadTask)?.urlAsset.url.absoluteString as Any,
                    "error": error.localizedDescription as Any,
                ])
        }
    }

    func urlSession(
        _ session: URLSession, assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        DownloadPathManager.write(
            url: assetDownloadTask.urlAsset.url.absoluteString, path: location.relativePath)
        sendEvent(
            .finished,
            [
                "url": assetDownloadTask.urlAsset.url.absoluteString
            ])
    }
}

extension Downloader: FlutterStreamHandler {
    func sendEvent(_ eventType: PlatformDownloadEventType, _ params: [String: Any] = [:]) {
        var paramsWithEvent = params
        paramsWithEvent["event"] = eventType.rawValue
        eventSink?(paramsWithEvent)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
