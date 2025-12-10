//
//  NowPlayingWidget.swift
//  widget
//
//  Created by Camille Scholtz on 09/12/2025.
//

import SwiftUI
import WidgetKit

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlayingWidget", provider: Provider()) { entry in
            NowPlayingWidgetEntryView(entry: entry)
                .containerBackground(.accent.gradient, for: .widget)
                .widgetURL(URL(string: "swmpc://nowplaying"))
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the currently playing song from your MPD server.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
