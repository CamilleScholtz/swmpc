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
}
