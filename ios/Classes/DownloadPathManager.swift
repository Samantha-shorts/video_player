//
//  DownloadPathManager.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/07/28.
//

import Foundation

class DownloadPathManager {
    private init() {}

    private static let PLIST_NAME = "downloads.plist"

    private static var plistUrl: URL {
        try! FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent(PLIST_NAME)
    }

    static func createPlistIfNotExist() {
        if !FileManager.default.fileExists(atPath: Self.plistUrl.absoluteString) {
            FileManager.default.createFile(
                atPath: Self.plistUrl.path, contents: nil, attributes: nil)
        }
    }

    private static func read() -> [String: String] {
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plistData = try? Data(contentsOf: Self.plistUrl),
            let dict = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: .mutableContainersAndLeaves,
                format: &format
            ) as? [String: String]
        else {
            return [:]
        }
        return dict
    }

    private static func write(dict: [String: String]) {
        let newData = try? PropertyListSerialization.data(
            fromPropertyList: dict, format: .xml, options: 0)
        try? newData?.write(to: Self.plistUrl)
    }

    static func write(url: String, path: String) {
        createPlistIfNotExist()

        var dict = read()
        dict[url] = path
        write(dict: dict)
    }

    static func remove(url: String) -> URL? {
        var dict = read()
        let path = dict.removeValue(forKey: url)
        write(dict: dict)
        return path.map {
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent($0)
        }
    }

    static func assetPath(forUrl url: String) -> String? {
        let dict = read()
        return dict[url]
    }

    static func assetUrl(forUrl url: String) -> URL? {
        assetPath(forUrl: url).map {
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent($0)
        }
    }
}
