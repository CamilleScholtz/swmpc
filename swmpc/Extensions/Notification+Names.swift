//
//  Notification+Names.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import SwiftUI

extension Notification.Name {
    static let performScrollNotification = Notification.Name(
        "perform_scroll_notification")
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
    static let showClearQueueAlertNotification = Notification.Name(
        "show_clear_queue_alert")
}

enum ButtonNotification: Hashable {
    case favorite
}
