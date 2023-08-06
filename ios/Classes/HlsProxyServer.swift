//
//  HlsProxyServer.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/08/06.
//

import Foundation
import GCDWebServer

class HlsProxyServer {
    private init() {}

    private let webServer = GCDWebServer()
    private let urlSession: URLSession = .shared
    private let m3u8ContentType = "application/vnd.apple.mpegurl"
    private let port: UInt = 3333
    private let originURLKey = "__hls_origin_url"
    private let subtitlesGroupID = "subs"
    private let subtitlesM3u8Path = "/__subtitles.m3u8"

    private var subsDict: [URL: [Subtitle]] = [:]

    static let shared = HlsProxyServer()

    struct Subtitle {
        let name: String
        let url: URL
        let language: String?

        init(name: String, url: URL, language: String?) {
            self.name = name
            self.url = url
            self.language = language
        }
    }

    func start() {
        if !webServer.isRunning {
            addPlaylistHandler()
            addSrtHandler()
            try! webServer.start(options: [
                GCDWebServerOption_Port: port,
                GCDWebServerOption_AutomaticallySuspendInBackground: false
            ])
        }
    }

    func stop() {
        if webServer.isRunning {
            webServer.stop()
        }
    }

    func m3u8ProxyURL(_ originURL: URL, subtitles: [Subtitle]?) -> URL? {
        subsDict[originURL] = subtitles
        return reverseProxyURL(from: originURL)
    }

    private func originURL(from request: GCDWebServerRequest) -> URL? {
        guard let encodedURLString = request.query?[originURLKey],
              let urlString = encodedURLString.removingPercentEncoding else {
            return nil
        }
        return URL(string: urlString)
    }

    /// Handler for m3u8
    private func addPlaylistHandler() {
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "^/.*\\.m3u8$",
            request: GCDWebServerRequest.self
        ) { [weak self] (request: GCDWebServerRequest, completion) in
            print("request: \(request.url)")
            guard let self = self else {
                return completion(GCDWebServerDataResponse(statusCode: 500))
            }
            guard let originURL = self.originURL(from: request) else {
                return completion(GCDWebServerErrorResponse(statusCode: 400))
            }

            if request.url.relativePath == subtitlesM3u8Path {
                var urlString: String
                if originURL.pathExtension == "srt" {
                    urlString = reverseProxyURL(from: originURL)!.absoluteString
                } else {
                    urlString = originURL.absoluteString
                }
                let m3u8 = """
#EXTM3U
#EXT-X-TARGETDURATION:99999999
#EXT-X-VERSION:3
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD

#EXTINF:99999999,
\(urlString)

#EXT-X-ENDLIST
"""
                print(m3u8)
                return completion(
                    GCDWebServerDataResponse(data: m3u8.data(using: .utf8)!, contentType: self.m3u8ContentType)
                )
            }

            let task = self.urlSession.dataTask(with: originURL) { [weak self] data, response, _ in
                guard let self = self, let data = data, let response = response else {
                    return completion(GCDWebServerErrorResponse(statusCode: 500))
                }
                let playlistData = self.reverseProxyPlaylist(with: data, forOriginURL: originURL)
                print(String(data: playlistData, encoding: .utf8)!)
                completion(
                    GCDWebServerDataResponse(data: playlistData, contentType: response.mimeType ?? self.m3u8ContentType)
                )
            }
            task.resume()
        }
    }

    func reverseProxyPlaylist(with data: Data, forOriginURL originURL: URL) -> Data {
        var lines = String(data: data, encoding: .utf8)!
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("#EXT-X-MEDIA:TYPE=SUBTITLES") }
            .map { processPlaylistLine($0, forOriginURL: originURL) }
            .map { line in
                if line.hasPrefix("#EXT-X-STREAM-INF:") {
                    return lineByReplaceOrAddSubtitles(line: line)
                } else {
                    return line
                }
            }
        if let subtitles = subsDict[originURL] {
            if let insertIndex = lines.firstIndex(where: { $0.hasPrefix("#EXT-X-STREAM-INF:")}) {
                lines.insert(contentsOf: subtitles.map {
"""
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="\(subtitlesGroupID)",NAME="\($0.name)",DEFAULT=NO,AUTOSELECT=NO\($0.language.map({ ",LANGUAGE=\($0)" }) ?? ""),URI="\(subtitleProxyURL(originURL: $0.url)!.absoluteString)"
"""
                }, at: insertIndex)
            }
        }

        return lines.joined(separator: "\n").data(using: .utf8)!
    }

    private func lineByReplaceOrAddSubtitles(line: String) -> String {
        let pattern = try! NSRegularExpression(pattern: "SUBTITLES=\"(.*)\"")
        let lineRange = NSRange(location: 0, length: line.count)
        guard let result = pattern.firstMatch(in: line, options: [], range: lineRange) else {
            return line + ",SUBTITLES=\"\(subtitlesGroupID)\""
        }
        return pattern.stringByReplacingMatches(
            in: line,
            options: [],
            range: lineRange,
            withTemplate: "SUBTITLES=\"\(subtitlesGroupID)\""
        )
    }

    private func subtitleProxyURL(originURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port)
        components.path = subtitlesM3u8Path

        let originURLQueryItem = URLQueryItem(name: originURLKey, value: originURL.absoluteString)
        components.queryItems = (components.queryItems ?? []) + [originURLQueryItem]

        return components.url
    }

    private func reverseProxyURL(from originURL: URL) -> URL? {
        guard var components = URLComponents(url: originURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port)

        let originURLQueryItem = URLQueryItem(name: originURLKey, value: originURL.absoluteString)
        components.queryItems = (components.queryItems ?? []) + [originURLQueryItem]

        return components.url
    }

    private func processPlaylistLine(_ line: String, forOriginURL originURL: URL) -> String {
        guard !line.isEmpty else { return line }
        if line.hasPrefix("#") {
            return lineByReplacingURI(line: line, forOriginURL: originURL)
        }
        if let originalSegmentURL = absoluteURL(from: line, forOriginURL: originURL) {
            return originalSegmentURL.absoluteString
        }
        return line
    }

    private func lineByReplacingURI(line: String, forOriginURL originURL: URL) -> String {
        let uriPattern = try! NSRegularExpression(pattern: "URI=\"(.*)\"")
        let lineRange = NSRange(location: 0, length: line.count)
        guard let result = uriPattern.firstMatch(in: line, options: [], range: lineRange) else {
            return line
        }

        let uri = (line as NSString).substring(with: result.range(at: 1))
        guard let absoluteURL = absoluteURL(from: uri, forOriginURL: originURL) else { return line }
        guard let reverseProxyURL = reverseProxyURL(from: absoluteURL) else { return line }

        return uriPattern.stringByReplacingMatches(in: line, options: [], range: lineRange, withTemplate: "URI=\"\(reverseProxyURL.absoluteString)\"")
    }

    private func absoluteURL(from line: String, forOriginURL originURL: URL) -> URL? {
        if line.hasPrefix("http://") || line.hasPrefix("https://") { // already absolute url
            return URL(string: line)
        }
        guard let scheme = originURL.scheme, let host = originURL.host else { return nil }
        let path: String
        if line.hasPrefix("/") {
            path = line
        } else {
            path = originURL.deletingLastPathComponent().appendingPathComponent(line).path
        }
        return URL(string: scheme + "://" + host + path)?.standardized
    }


    /// Handler for srt file
    private func addSrtHandler() {
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "^/.*\\.srt$",
            request: GCDWebServerRequest.self
        ) { [weak self] (request: GCDWebServerRequest, completion) in
            guard let self = self else {
                return completion(GCDWebServerDataResponse(statusCode: 500))
            }
            guard let originURL = self.originURL(from: request) else {
                return completion(GCDWebServerErrorResponse(statusCode: 400))
            }

            let task = self.urlSession.dataTask(with: originURL) { [weak self] data, response, _ in
                guard let self = self, let data = data, let response = response else {
                    return completion(GCDWebServerErrorResponse(statusCode: 500))
                }
                let srt = String(data: data, encoding: .utf8)!
                let vtt = convertSrtToVtt(srt)
                completion(
                    GCDWebServerDataResponse(data: vtt.data(using: .utf8)!, contentType: response.mimeType ?? "plain/txt")
                )
            }
            task.resume()
        }
    }

    private func convertSrtToVtt(_ str: String) -> String {
        let pattern = "(\\d+:\\d+:\\d+),(\\d+)\\s*-->\\s*(\\d+:\\d+:\\d+),(\\d+)"
        let replacement = "$1.$2 --> $3.$4"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let result = regex.stringByReplacingMatches(in: str, options: [], range: NSRange(str.startIndex..<str.endIndex, in: str), withTemplate: replacement)
            return "WEBVTT\n\(result)"
        }
        return "WEBVTT\n\(str)"
    }
}
