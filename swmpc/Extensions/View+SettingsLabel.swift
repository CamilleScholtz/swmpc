//
//  View+SettingsLabel.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/09/2025.
//

import SwiftUI

/// A label view for settings forms with platform-appropriate formatting.
///
/// On macOS, appends a colon to the label text following macOS Human Interface
/// Guidelines for form labels. On iOS, displays the text without a colon.
struct SettingsLabel: View {
    /// The localized string key for the label text.
    let key: LocalizedStringKey

    /// Creates a settings label with the specified localized string key.
    ///
    /// - Parameter key: The localized string key for the label text.
    init(_ key: LocalizedStringKey) {
        self.key = key
    }

    var body: some View {
        #if os(macOS)
            HStack(spacing: 0) {
                Text(key)
                Text(":")
            }
        #else
            Text(key)
        #endif
    }
}
