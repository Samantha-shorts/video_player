//
//  Downloader.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/07/26.
//

import AVKit
import Flutter

class Downloader: NSObject {
    enum Quality { case low, medium, high }

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

    func startDownload(key: String, url: URL, headers: [String: String]?, quality: Quality) {
        let options = ["AVURLAssetHTTPHeaderFieldsKey": headers ?? [:]]
        let asset = AVURLAsset(url: url, options: options)
        let assetTitle = url.lastPathComponent

        // FairPlay の準備は現状どおり
        ContentKeyManager.shared.contentKeySession.addContentKeyRecipient(asset)
        asset.resourceLoader.preloadsEligibleContentKeys = true

        // ★ ここでマスター m3u8 を読んでビットレートを決める
        let selectedBitrate = selectBitrateForQuality(masterURL: url, headers: headers, fallback: quality)

        var dlOptions: [String: Any] = options
        if let br = selectedBitrate {
            dlOptions[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = NSNumber(value: br)
        }

        let downloadTask = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: assetTitle,
            assetArtworkData: nil,
            options: dlOptions
        )
        downloadTask?.resume()
        DownloadPathManager.add(key: key, url: url.absoluteString)
    }

    private func selectBitrateForQuality(masterURL: URL, headers: [String: String]?, fallback: Quality) -> Int? {
        // マスター playlist を取得（同期）
        var request = URLRequest(url: masterURL)
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let semaphore = DispatchSemaphore(value: 1)
        var data: Data?
        var response: URLResponse?
        var error: Error?

        URLSession.shared.dataTask(with: request) { d, r, e in
            data = d; response = r; error = e
            semaphore.signal()
        }.resume()
        semaphore.wait()

        guard error == nil, let body = data.flatMap({ String(data: $0, encoding: .utf8) }) else {
            // 失敗時は閾値の固定値（例）にフォールバック
            switch fallback {
            case .low:    return 600_000
            case .medium: return 2_000_000
            case .high:   return 5_000_000
            }
        }

        // #EXT-X-STREAM-INF の BANDWIDTH を全て取り出す
        // 例: #EXT-X-STREAM-INF:BANDWIDTH=800000,AVERAGE-BANDWIDTH=600000,...
        let lines = body.components(separatedBy: .newlines)
        var bandwidths = [Int]()
        let pattern = #"BANDWIDTH=(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        for line in lines where line.contains("#EXT-X-STREAM-INF:") {
            if let m = regex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let r = Range(m.range(at: 1), in: line),
            let bw = Int(line[r]) {
                bandwidths.append(bw)
            }
        }

        guard !bandwidths.isEmpty else {
            // 候補が取れなければ固定閾値へ
            switch fallback {
            case .low:    return 600_000
            case .medium: return 2_000_000
            case .high:   return 5_000_000
            }
        }

        let sorted = bandwidths.sorted()
        switch fallback {
        case .low:
            return sorted.first
        case .high:
            return sorted.last
        case .medium:
            return sorted[sorted.count / 2]
        }
    }

    func getAllDownloadTasks(_ completion: @escaping ([AVAssetDownloadTask]) -> Void) {
        downloadSession.getAllTasks { tasks in
            completion(tasks.compactMap { $0 as? AVAssetDownloadTask })
        }
    }

    private func getDownloadTask(key: String, completion: @escaping (AVAssetDownloadTask?) -> Void)
    {
        guard let url = DownloadPathManager.url(forKey: key) else {
            completion(nil)
            return
        }
        getAllDownloadTasks { tasks in
            let task = tasks.first(where: { $0.urlAsset.url.absoluteString == url })
            completion(task)
        }
    }

    func pauseDownload(key: String, completion: ((AVAssetDownloadTask?) -> Void)? = nil) {
        getDownloadTask(key: key) { [weak self] task in
            task?.suspend()
            if task != nil {
                self?.sendEvent(.paused, ["key": key])
            }
            completion?(task)
        }
    }

    func resumeDownload(key: String, completion: ((AVAssetDownloadTask?) -> Void)? = nil) {
        getDownloadTask(key: key) { [weak self] task in
            task?.resume()
            if task != nil {
                self?.sendEvent(.resumed, ["key": key])
            }
            completion?(task)
        }
    }

    func cancelDownload(key: String, completion: ((AVAssetDownloadTask?) -> Void)? = nil) {
        getDownloadTask(key: key) { [weak self] task in
            task?.cancel()
            if task != nil {
                self?.sendEvent(.canceled, ["key": key])
            }
            completion?(task)
        }
    }

    func deleteOfflineAsset(key: String) {
        guard let value = DownloadPathManager.remove(key),
            let path = value["path"] else {
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
        sendEvent(.progress, [
            "key": key,
            "progress": percentComplete,
            "bytesDownloaded": assetDownloadTask.countOfBytesReceived,
            "bytesTotal": assetDownloadTask.countOfBytesExpectedToReceive
        ])
    }

    private func isCancelError(error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        guard let error = error else {
            return
        }
        let url = (task as? AVAssetDownloadTask)?.urlAsset.url.absoluteString
        let key = url.flatMap { DownloadPathManager.key(forUrl: $0) }
        if isCancelError(error: error) {
            if let key = key {
                DownloadPathManager.remove(key)
            }
            sendEvent(.canceled, [
                "key": key as Any
            ])
        } else {
            sendEvent(.error, [
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

        print("[DEBUG][download] finished. source=\(assetDownloadTask.urlAsset.url.absoluteString)")
        print("[DEBUG][download] saved absolute path: \(location.path)")
        print("[DEBUG][download] file exists? \(FileManager.default.fileExists(atPath: location.path))")

        let url = assetDownloadTask.urlAsset.url.absoluteString
        guard let key = DownloadPathManager.key(forUrl: url) else {
            fatalError("key not found for url \(url)")
        }
        sendEvent(.finished, ["key": key])
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
