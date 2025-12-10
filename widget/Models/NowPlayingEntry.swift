//
//  NowPlayingEntry.swift
//  widget
//
//  Created by Camille Scholtz on 09/12/2025.
//

import Foundation
import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let artwork: PlatformImage?
    let title: String
    let artist: String
    let isPlaying: Bool
}
