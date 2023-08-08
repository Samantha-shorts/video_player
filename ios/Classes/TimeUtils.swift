//
//  TimeUtils.swift
//  video_player
//
//  Created by Yuma Matsune on 2023/06/25.
//

import CoreMedia

class TimeUtils {
    static func FLTCMTimeToMillis(_ time: CMTime) -> Int {
        let timeInSeconds = CMTimeGetSeconds(time)
        let timeInMillis = timeInSeconds * 1000.0
        if !timeInMillis.isFinite {
            return 0
        }
        return Int(round(timeInMillis))
    }

    static func FLTNSTimeIntervalToMillis(_ interval: TimeInterval) -> Int {
        let timeInMillis = interval * 1000.0
        if !timeInMillis.isFinite {
            return 0
        }
        return Int(timeInMillis)
    }
}
