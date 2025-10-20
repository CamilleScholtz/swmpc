//
//  String+Width.swift
//  swmpc
//
//  Created by Camille Scholtz on 17/10/2025.
//

import SwiftUI

#if os(macOS)
    extension String {
        /// Calculates the width of the string when rendered with a given font.
        ///
        /// This method uses `NSAttributedString` to determine the size the string
        /// would occupy when rendered with the specified font. Useful for layout
        /// calculations and dynamic positioning based on text content.
        ///
        /// - Parameter font: The `NSFont` to use for calculating the width.
        /// - Returns: The width in points that the string occupies when rendered.
        func width(withFont font: NSFont) -> CGFloat {
            let attributes = [NSAttributedString.Key.font: font]
            let size = (self as NSString).size(withAttributes: attributes)

            return size.width
        }
    }
#endif
