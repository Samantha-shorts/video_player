//
//  DownloadPathManager.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/07/28.
//

import Foundation

class DownloadPathManager {
    private init() {}

    private static let PLIST_NAME = "video_player_downloads.plist"
    typealias Value = [String: String]
    typealias KeyValue = [String: Value]

    private static var plistUrl: URL {
        try! FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent(PLIST_NAME)
    }

    static func createPlistIfNotExist() {
        if !FileManager.default.fileExists(atPath: Self.plistUrl.path) {
            FileManager.default.createFile(
                atPath: Self.plistUrl.path, contents: nil, attributes: nil)
        }
    }

    static func read() -> KeyValue {
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plistData = try? Data(contentsOf: Self.plistUrl),
            let dict = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: .mutableContainersAndLeaves,
                format: &format
            ) as? KeyValue else {
            return [:]
        }
        return dict
    }

    private static func write(_ kv: KeyValue) {
        let newData = try? PropertyListSerialization.data(
            fromPropertyList: kv, format: .xml, options: 0)
        try? newData?.write(to: Self.plistUrl)
    }

    static func add(key: String, url: String) {
        createPlistIfNotExist()

        var dict = read()
        let value: Value = ["url": url]
        dict[key] = value
        write(dict)
    }

    @discardableResult
    static func remove(_ key: String) -> Value? {
        var dict = read()
        let value = dict.removeValue(forKey: key)
        write(dict)
        return value
    }

    static func key(forUrl url: String) -> String? {
        let dict = read()
        return dict.first(where: { $0.value["url"] == url })?.key
    }

    static func url(forKey key: String) -> String? {
        let dict = read()
        return dict.first(where: { $0.key == key })?.value["url"]
    }

    static func writePath(forUrl url: String, path: String) {
        var dict = read()
        if let key = key(forUrl: url) {
            dict[key]?["path"] = path
        }
        write(dict)
    }

    static func assetPath(forKey key: String) -> String? {
        let value = read()[key]
        return value?["path"]
    }

    static func sync() {
        let dict = read().filter { (key, value) in
            if let path = value["path"] {
                // remove if downloaded asset doesn't exist
                let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(path)
                return FileManager.default.fileExists(atPath: url.path)
            }
            return true
        }
        write(dict)
    }
}
