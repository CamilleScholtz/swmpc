//
//  Constants.swift
//  MPDKit
//
//  Created by Camille Scholtz on 08/01/2025.
//

import SwiftUI

#if os(iOS)
    public typealias PlatformImage = UIImage
#elseif os(macOS)
    public typealias PlatformImage = NSImage
#endif

public enum Layout {
    public enum Padding {
        public static let small: CGFloat = 7.5
        public static let medium: CGFloat = 10
        public static let large: CGFloat = 15
    }

    public enum Spacing {
        public static let small: CGFloat = 7.5
        public static let medium: CGFloat = 10
        public static let large: CGFloat = 15
    }

    public enum CornerRadius {
        public static let small: CGFloat = 12
        public static let medium: CGFloat = 18
        public static let large: CGFloat = 30
        public static let rounded: CGFloat = 100
    }

    public enum Size {
        #if os(macOS)
            public static let sidebarWidth: CGFloat = 190
            public static let contentWidth: CGFloat = 310
            public static let detailWidth: CGFloat = 650
        #endif

        #if os(iOS)
            public static let artworkWidth: CGFloat = 300
        #elseif os(macOS)
            public static let artworkWidth: CGFloat = 250
        #endif

        public static let popoverFooterHeight: CGFloat = 80

        public static let popoverContentWidth: CGFloat = 220 // popoverWidth - 30

        public static let dotIndicator: CGFloat = 4
    }

    public enum RowHeight {
        #if os(iOS)
            public static let album: CGFloat = 75
            public static let artist: CGFloat = 60
            public static let song: CGFloat = 41.5
        #elseif os(macOS)
            public static let album: CGFloat = 65
            public static let artist: CGFloat = 50
            public static let song: CGFloat = 31.5
        #endif
    }

    public enum Colors {
        #if os(iOS)
            public static let systemBackground = Color(.systemBackground)
        #elseif os(macOS)
            public static let systemBackground = Color(.textBackgroundColor)
        #endif
    }
}
