//
//  HlsProxyServer.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/08/06.
//

import Foundation
import GCDWebServer
import os

extension OSLog {
    static let proxyServer = OSLog(subsystem: "matsune.videoPlayer", category: "HlsProxyServer")
}

class HlsProxyServer {
    init() {}

    let webServer = GCDWebServer()
    private let urlSession: URLSession = .shared
    private let m3u8ContentType = "application/vnd.apple.mpegurl"
    private let originURLKey = "__hls_origin_url"
    private let subtitlesGroupID = "subs"
    private let subtitlesM3u8Path = "/__proxy_subtitles.m3u8"
    private var configs: [URL: RequestConfig] = [:]

    struct Subtitle {
        let name: String
        let url: URL
        let language: String?

        init(name: String, url: URL, language: String? = nil) {
            self.name = name
            self.url = url
            self.language = language
        }
    }

    private struct RequestConfig {
        let headers: [String: String]?
        let subtitles: [Subtitle]?
    }

    func start() {
        if !webServer.isRunning {
            addHealthcheckHandler()
            addPlaylistHandler()
            addSrtHandler()
            addVttHandler()
            do {
                try webServer.start(options: [
                    GCDWebServerOption_AutomaticallySuspendInBackground: false,
                    GCDWebServerOption_BindToLocalhost: true
                ])
            } catch {
                os_log("%@", log: .proxyServer, type: .error, error.localizedDescription)
            }
        }
    }

    func stop() {
        if webServer.isRunning {
            webServer.stop()
        }
    }

    func m3u8ProxyURL(_ originURL: URL, headers: [String: String]?, subtitles: [Subtitle]?) -> URL? {
        configs[originURL] = .init(headers: headers, subtitles: subtitles)
        return reverseProxyURL(from: originURL)
    }

    private func originURL(from request: GCDWebServerRequest) -> URL? {
        guard let encodedURLString = request.query?[originURLKey],
              let urlString = encodedURLString.removingPercentEncoding else {
            return nil
        }
        return URL(string: urlString)
    }

    private func addHealthcheckHandler() {
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "^/_healthcheck$",
            request: GCDWebServerRequest.self
        ) { (request: GCDWebServerRequest, completion) in
            completion(GCDWebServerResponse(statusCode: 200))
        }
    }

    /// Handler for m3u8
    private func addPlaylistHandler() {
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "^/.*\\.m3u8$",
            request: GCDWebServerRequest.self
        ) { [weak self] (request: GCDWebServerRequest, completion) in
            guard let self = self else {
                return completion(GCDWebServerDataResponse(statusCode: 500))
            }
            guard let originURL = self.originURL(from: request) else {
                return completion(GCDWebServerErrorResponse(statusCode: 400))
            }
            os_log("%@", log: .proxyServer, type: .info, "originURL: \(originURL.absoluteString)")
            if request.url.relativePath == subtitlesM3u8Path {
                let url: URL
                if ["srt", "vtt", "webvtt"].contains(originURL.pathExtension) {
                    url = reverseProxyURL(from: originURL)!
                } else {
                    url = originURL
                }
                let m3u8 = """
                #EXTM3U
                #EXT-X-TARGETDURATION:99999999
                #EXT-X-VERSION:3
                #EXT-X-MEDIA-SEQUENCE:0
                #EXT-X-PLAYLIST-TYPE:VOD

                #EXTINF:99999999,
                \(url.absoluteString)

                #EXT-X-ENDLIST
                """
//                os_log("%@", log: .proxyServer, type: .debug, m3u8)
                return completion(
                    GCDWebServerDataResponse(data: m3u8.data(using: .utf8)!, contentType: self.m3u8ContentType)
                )
            }

            var request = URLRequest(url: originURL)
            if let headers = self.configs[originURL]?.headers {
                headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
            }
            let task = self.urlSession.dataTask(with: request) { [weak self] data, response, _ in
                guard let self = self, let data = data, let response = response else {
                    return completion(GCDWebServerErrorResponse(statusCode: 500))
                }
                let m3u8 = self.rewriteM3u8(with: data, forOriginURL: originURL)
//                os_log("%@", log: .proxyServer, type: .debug, m3u8)
                completion(
                    GCDWebServerDataResponse(
                        data: m3u8.data(using: .utf8)!,
                        contentType: response.mimeType ?? self.m3u8ContentType
                    )
                )
            }
            task.resume()
        }
    }

    private func rewriteM3u8(with data: Data, forOriginURL originURL: URL) -> String {
        var lines = String(data: data, encoding: .utf8)!
            .components(separatedBy: .newlines)
            .map { rewriteM3u8Line($0, forOriginURL: originURL) }
        if let subtitles = configs[originURL]?.subtitles, !subtitles.isEmpty {
            // replace subtitles
            var newLines = lines
                .filter { !$0.hasPrefix("#EXT-X-MEDIA:TYPE=SUBTITLES") } // remove embedded subtitles
                .map { line in
                    if line.hasPrefix("#EXT-X-STREAM-INF:") {
                        return lineByReplaceOrAddSubtitles(line: line)
                    } else {
                        return line
                    }
                }
            if let headIndex = newLines.firstIndex(where: { $0.hasPrefix("#EXTM3U")}) {
                newLines.insert(contentsOf: subtitles.map(subtitleMediaTag), at: headIndex + 1)
                lines = newLines
            }
        }
        return lines.joined(separator: "\n")
    }

    private func subtitleMediaTag(_ subtitle: Subtitle) -> String {
        let languageComponent = subtitle.language.map({ "LANGUAGE=\($0)," }) ?? ""
        return """
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="\(subtitlesGroupID)",NAME="\(subtitle.name)",\
        DEFAULT=NO,AUTOSELECT=NO,\
        \(languageComponent)\
        URI="\(subtitleProxyURL(originURL: subtitle.url)!.absoluteString)"
        """
    }

    private func lineByReplaceOrAddSubtitles(line: String) -> String {
        let patternString = "SUBTITLES=\"(.*)\""
        guard let pattern = try? NSRegularExpression(pattern: patternString) else {
            return line
        }
        let lineRange = NSRange(location: 0, length: line.count)
        let matches = pattern.matches(in: line, options: [], range: lineRange)
        if matches.isEmpty {
            // add SUBTITLES attribute if there's no match
            return line + ",SUBTITLES=\"\(subtitlesGroupID)\""
        } else {
            return pattern.stringByReplacingMatches(
                in: line,
                options: [],
                range: lineRange,
                withTemplate: "SUBTITLES=\"\(subtitlesGroupID)\""
            )
        }
    }

    private func subtitleProxyURL(originURL: URL) -> URL? {
        guard let serverURL = webServer.serverURL else {
            return nil
        }
        var components = URLComponents()
        components.scheme = serverURL.scheme
        components.host = serverURL.host
        components.port = serverURL.port
        components.path = subtitlesM3u8Path

        let originURLQueryItem = URLQueryItem(name: originURLKey, value: originURL.absoluteString)
        components.queryItems = (components.queryItems ?? []) + [originURLQueryItem]

        return components.url
    }

    private func reverseProxyURL(from originURL: URL) -> URL? {
        guard let serverURL = webServer.serverURL,
              var components = URLComponents(url: originURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = serverURL.scheme
        components.host = serverURL.host
        components.port = serverURL.port
        let originURLQueryItem = URLQueryItem(name: originURLKey, value: originURL.absoluteString)
        components.queryItems = (components.queryItems ?? []) + [originURLQueryItem]
        return components.url
    }

    private func rewriteM3u8Line(_ line: String, forOriginURL originURL: URL) -> String {
        guard !line.isEmpty else { return line }
        if line.hasPrefix("#") {
            // tag line
            return replaceTagLineURI(line, forOriginURL: originURL)
        } else {
            // URI line
            if let originalSegmentURL = absoluteURL(from: line, forOriginURL: originURL) {
                return originalSegmentURL.absoluteString
            }
            return line
        }
    }

    /// Replace origin URI with proxy URI.
    private func replaceTagLineURI(_ line: String, forOriginURL originURL: URL) -> String {
        let uriPattern = try! NSRegularExpression(pattern: "URI=\"(.*)\"")
        let lineRange = NSRange(location: 0, length: line.count)
        guard let result = uriPattern.firstMatch(in: line, options: [], range: lineRange) else {
            return line
        }
        let uri = (line as NSString).substring(with: result.range(at: 1))
        guard let absoluteURL = absoluteURL(from: uri, forOriginURL: originURL),
                let reverseProxyURL = reverseProxyURL(from: absoluteURL) else {
            return line
        }
        return uriPattern.stringByReplacingMatches(
            in: line,
            options: [],
            range: lineRange,
            withTemplate: "URI=\"\(reverseProxyURL.absoluteString)\""
        )
    }

    /// Get absolute URL if the line is relative URL.
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

    private func addVttHandler() {
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "^/.*\\.(vtt|webvtt)$",
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
                let content = String(data: data, encoding: .utf8)!
                let vtt = self.modifyVtt(content)
                completion(
                    GCDWebServerDataResponse(data: vtt.data(using: .utf8)!, contentType: response.mimeType ?? "text/vtt")
                )
            }
            task.resume()
        }
    }

    private func modifyVtt(_ str: String) -> String {
        if str.contains("WEBVTT") && !str.contains("X-TIMESTAMP-MAP=") {
            let insertLine = "X-TIMESTAMP-MAP=MPEGTS:200000,LOCAL:00:00:00.000\n"
            let modifiedStr = str.replacingOccurrences(of: "WEBVTT\n", with: "WEBVTT\n" + insertLine)
            return modifiedStr
        }
        return str
    }
}
