//
//  Double.swift
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
        var hours = self / 3600
        hours.round(.down)
        let minutes = (self - hours * 3600) / 60

        if hours < 1 {
            return String(format: "%02dm", Int(minutes))
        }

        return String(format: "%01dh %02dm", Int(hours), Int(minutes))
    }
}
