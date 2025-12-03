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

    /// Notification when status bar display settings change (macOS).
    static let statusBarSettingChangedNotification = Notification.Name(
        "status_bar_setting_changed")

    /// Notification when a playlist has been modified.
    static let playlistModifiedNotification = Notification.Name(
        "playlist_modified")
}

/// Represents button-related notifications that can be sent through the app.
enum ButtonNotification: Hashable {
    case favorite
}
