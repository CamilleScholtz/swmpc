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
    static let createIntelligencePlaylistNotification = Notification.Name(
        "create_intelligence_playlist")
}

enum ButtonNotification: Hashable {
    case favorite
}
