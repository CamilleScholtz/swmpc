//
//  Constants.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/01/2025.
//

import SwiftUI

#if os(iOS)
    typealias PlatformImage = UIImage
#elseif os(macOS)
    typealias PlatformImage = NSImage
#endif

enum Layout {
    enum Padding {
        static let small: CGFloat = 7.5
        static let medium: CGFloat = 10
        static let large: CGFloat = 15
    }

    enum Spacing {
        static let small: CGFloat = 7.5
        static let medium: CGFloat = 10
        static let large: CGFloat = 15
    }

    enum CornerRadius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 30
        static let rounded: CGFloat = 100
    }

    enum Size {
        #if os(macOS)
            static let sidebarWidth: CGFloat = 180
            static let contentWidth: CGFloat = 310
            static let detailWidth: CGFloat = 650
        #endif

        #if os(iOS)
            static let artworkWidth: CGFloat = 300
        #elseif os(macOS)
            static let artworkWidth: CGFloat = 250
        #endif

        static let popoverFooterHeight: CGFloat = 80

        static let popoverContentWidth: CGFloat = 220 // popoverWidth - 30

        static let dotIndicator: CGFloat = 4
    }

    enum RowHeight {
        #if os(iOS)
            static let album: CGFloat = 75
            static let artist: CGFloat = 60
            static let song: CGFloat = 41.5
        #elseif os(macOS)
            static let album: CGFloat = 65
            static let artist: CGFloat = 50
            static let song: CGFloat = 31.5
        #endif
    }
}
