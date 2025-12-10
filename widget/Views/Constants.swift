//
//  Constants.swift
//  widget
//
//  Created by Camille Scholtz on 09/12/2025.
//

import SwiftUI

#if os(iOS)
    public typealias PlatformImage = UIImage
#elseif os(macOS)
    public typealias PlatformImage = NSImage
#endif
