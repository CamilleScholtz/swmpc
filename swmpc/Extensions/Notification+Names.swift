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
    static let statusBarSettingChangedNotification = Notification.Name(
        "status_bar_setting_changed")
    #if !DISABLE_INTELLIGENCE
        static let createIntelligencePlaylistNotification = Notification.Name(
            "create_intelligence_playlist")
    #endif
}

enum ButtonNotification: Hashable {
    case favorite
}
