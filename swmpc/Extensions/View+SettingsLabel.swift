//
//  View+SettingsLabel.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/09/2025.
//

import SwiftUI

extension String {
    var settingsLabel: String {
        #if os(macOS)
            return hasSuffix(":") ? self : self + ":"
        #else
            return self
        #endif
    }
}
