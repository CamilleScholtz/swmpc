//
//  Notification+Names.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import SwiftUI

extension Notification.Name {
    /// Notification to trigger scrolling behavior in views.
    static let performScrollNotification = Notification.Name(
        "perform_scroll_notification")

    /// Notification to initiate search mode in the UI.
    static let startSearchingNotication = Notification.Name(
        "start_searching")

    /// Notification to fill a playlist using AI intelligence features.
    static let fillIntelligencePlaylistNotification = Notification.Name(
        "fill_intelligence_playlist")

    /// Notification to fill the playback queue using AI intelligence features.
    static let fillIntelligenceQueueNotification = Notification.Name(
        "fill_intelligence_queue")

    /// Notification when status bar display settings change (macOS).
    static let statusBarSettingChangedNotification = Notification.Name(
        "status_bar_setting_changed")

    /// Notification when a playlist has been modified.
    static let playlistModifiedNotification = Notification.Name(
        "playlist_modified")

    /// Notification to display an alert for clearing the queue.
    static let showClearQueueAlertNotification = Notification.Name(
        "show_clear_queue_alert")
}

/// Represents button-related notifications that can be sent through the app.
enum ButtonNotification: Hashable {
    case favorite
}
