//
//  Notification+Names.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import SwiftUI

extension Notification.Name {
    static let scrollToCurrentNotification = Notification.Name(
        "scroll_to_current")
    static let startSearchingNotication = Notification.Name(
        "start_searching")
    static let fillIntelligencePlaylistNotification = Notification.Name(
        "fill_intelligence_playlist")
    static let fillIntelligenceQueueNotification = Notification.Name(
        "fill_intelligence_queue")
    static let statusBarSettingChangedNotification = Notification.Name(
        "status_bar_setting_changed")
    static let playlistModifiedNotification = Notification.Name(
        "playlist_modified")
}

enum ButtonNotification: Hashable {
    case favorite
}
