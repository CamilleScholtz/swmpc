//
//  View+SettingsLabel.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/09/2025.
//

import SwiftUI

struct SettingsLabel: View {
    let key: LocalizedStringKey

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
