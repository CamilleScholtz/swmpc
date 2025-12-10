//
//  widgetBundle.swift
//  widget
//
//  Created by Camille Scholtz on 09/12/2025.
//

import SwiftUI
import WidgetKit

@main
struct swmpcWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
        NowPlayingAltWidget()
    }
}
