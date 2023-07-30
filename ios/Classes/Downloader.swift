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

    func startDownload(key: String, url: URL, headers: [String: String]?) {
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers ?? [:]])
        let assetTitle = url.lastPathComponent
        let downloadTask = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: assetTitle,
            assetArtworkData: nil,
            options: nil
        )
        downloadTask?.resume()
        DownloadPathManager.add(key: key, url: url.absoluteString)
    }

    func getAllDownloadTasks(_ completion: @escaping ([AVAssetDownloadTask]) -> Void) {
        downloadSession.getAllTasks { tasks in
            completion(tasks.compactMap { $0 as? AVAssetDownloadTask })
        }
    }

    func deleteOfflineAsset(key: String) {
        guard let value = DownloadPathManager.remove(key),
            let path = value["path"]
        else {
            return
        }
        let assetURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(path)
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
        let url = assetDownloadTask.urlAsset.url.absoluteString
        guard let key = DownloadPathManager.key(forUrl: url) else {
            fatalError("key not found for url \(url)")
        }

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
                "key": key,
                "progress": percentComplete,
            ])
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        if let error = error {
            let url = task.originalRequest?.url?.absoluteString
            let key = url.flatMap { DownloadPathManager.key(forUrl: $0) }
            sendEvent(
                .error,
                [
                    "key": key as Any,
                    "error": error.localizedDescription as Any,
                ])
        }
    }

    func urlSession(
        _ session: URLSession, assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        DownloadPathManager.writePath(
            forUrl: assetDownloadTask.urlAsset.url.absoluteString,
            path: location.relativePath
        )
        let url = assetDownloadTask.urlAsset.url.absoluteString
        guard let key = DownloadPathManager.key(forUrl: url) else {
            fatalError("key not found for url \(url)")
        }
        sendEvent(
            .finished,
            [
                "key": key
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
