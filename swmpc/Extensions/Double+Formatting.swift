//
//  Double+Formatting.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

extension Double {
    /// Returns a string formatted as a time in the format "M:SS" or "MM:SS".
    /// Assumes the value represents time in seconds.
    ///
    /// - Returns: A string representing the time in minutes and seconds.
    var timeString: String {
        var minutes = self / 60
        minutes.round(.down)
        let seconds = self - minutes * 60

        return String(format: "%01d:%02d", Int(minutes), Int(seconds))
    }

    /// Returns a human-readable string representation of time duration.
    ///
    /// For durations less than 60 seconds, shows as abbreviated minutes (e.g.,
    /// "1m"). For longer durations, shows hours and minutes (e.g., "2h 30m").
    /// Assumes the value represents time in seconds.
    ///
    /// - Returns: A localized, abbreviated string representing the duration.
    var humanTimeString: String {
        if self < 60 {
            let minuteFormatter = DateComponentsFormatter()

            minuteFormatter.allowedUnits = [.minute]
            minuteFormatter.unitsStyle = .abbreviated

            return minuteFormatter.string(from: self)!
        }

        let formatter = DateComponentsFormatter()

        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowsFractionalUnits = false

        return formatter.string(from: self)!
    }
}
