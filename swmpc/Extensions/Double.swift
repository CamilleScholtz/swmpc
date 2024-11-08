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
}
