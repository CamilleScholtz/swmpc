//
//  NowPlayingAltWidget.swift
//  widget
//
//  Created by Camille Scholtz on 09/12/2025.
//

import SwiftUI
import WidgetKit

struct NowPlayingAltWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlayingAltWidget", provider: Provider()) { entry in
            NowPlayingAltWidgetEntryView(entry: entry)
                .containerBackground(.accent.gradient, for: .widget)
                .widgetURL(URL(string: "swmpc://nowplaying"))
        }
        .configurationDisplayName("Now Playing Alt")
        .description("Alternative widget showing the currently playing song.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
