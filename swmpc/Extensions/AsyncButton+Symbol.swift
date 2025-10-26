//
//  AsyncButton+Symbol.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI

extension AsyncButton where P == IndeterminateProgress, S == Label<Text, Image> {
    /// Creates an async button with a text label and SF Symbol icon.
    ///
    /// - Parameters:
    ///   - titleKey: The localized string key for the button's title.
    ///   - systemSymbol: The SF Symbol to display.
    ///   - role: An optional semantic role that describes the button's purpose.
    ///   - action: The async action to perform when the button is pressed.
    @_disfavoredOverload
    init(
        _ titleKey: LocalizedStringKey,
        systemSymbol: SFSymbol,
        role: ButtonRole? = nil,
        action: @escaping () async throws -> Void,
    ) {
        self.init(titleKey, systemImage: systemSymbol.rawValue, role: role,
                  action: action)
    }

    /// Creates an async button with a text label and SF Symbol icon.
    ///
    /// - Parameters:
    ///   - title: The string for the button's title.
    ///   - systemSymbol: The SF Symbol to display.
    ///   - role: An optional semantic role that describes the button's purpose.
    ///   - action: The async action to perform when the button is pressed.
    @_disfavoredOverload
    init(
        _ title: some StringProtocol,
        systemSymbol: SFSymbol,
        role: ButtonRole? = nil,
        action: @escaping () async throws -> Void,
    ) {
        self.init(title, systemImage: systemSymbol.rawValue, role: role,
                  action: action)
    }
}

extension AsyncButton where P == IndeterminateProgress, S == Image {
    /// Creates an async button that displays an SF Symbol icon.
    ///
    /// - Parameters:
    ///   - systemSymbol: The SF Symbol to display.
    ///   - role: An optional semantic role that describes the button's purpose.
    ///   - action: The async action to perform when the button is pressed.
    @_disfavoredOverload
    init(
        systemSymbol: SFSymbol,
        role: ButtonRole? = nil,
        action: @escaping () async throws -> Void,
    ) {
        self.init(role: role, action: action) {
            Image(systemSymbol: systemSymbol)
        }
    }
}
