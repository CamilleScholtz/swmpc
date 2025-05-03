//
//  String+Clipboard.swift
//  swmpc
//
//  Created by Camille Scholtz on 19/04/2025.
//

import SwiftUI

#if os(iOS)
    public typealias Pasteboard = UIPasteboard
#elseif os(macOS)
    public typealias Pasteboard = NSPasteboard
#endif

public extension String {
    /// Copies the current string instance to the system's general pasteboard.
    func copyToClipboard() {
        #if os(iOS)
            Pasteboard.general.string = self
        #elseif os(macOS)
            let pasteboard = Pasteboard.general

            pasteboard.clearContents()
            pasteboard.setString(self, forType: .string)
        #endif
    }

    /// Retrieves a string from the system's general pasteboard, if one exists.
    ///
    /// - Returns: An optional `String` containing the text content from the
    ///            pasteboard, or `nil` if the pasteboard is empty or does not
    ///            contain a string.
    static func fromClipboard() -> String? {
        #if os(iOS)
            return Pasteboard.general.string
        #elseif os(macOS)
            return Pasteboard.general.string(forType: .string)
        #endif
    }
}
