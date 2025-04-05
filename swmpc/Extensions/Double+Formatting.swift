//
//  Double+Formatting.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

extension Double {
    var timeString: String {
        var minutes = self / 60
        minutes.round(.down)
        let seconds = self - minutes * 60

        return String(format: "%01d:%02d", Int(minutes), Int(seconds))
    }

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
