//
//  View+MediaList.swift
//  swmpc
//
//  Created by Camille Scholtz on 05/09/2025.
//

import SwiftUI

/// View modifiers for consistent media list styling across the app.
extension View {
    /// Applies consistent styling to media lists.
    ///
    /// Configures the list with a plain style, bottom safe area padding, and
    /// optionally sets the minimum row height based on the provided content
    /// height. Row height calculation accounts for platform-specific padding
    /// differences.
    ///
    /// - Parameters:
    ///   - rowHeight: The height of the row content (excluding padding). Whe
    ///                provided, the minimum list row height is set to this
    ///                value plus platform-appropriate padding.
    ///   - bottomMargin: Safe area padding at the bottom of the list. Defaults
    ///                   to `Layout.Spacing.small`.
    /// - Returns: A view with media list styling applied.
    @ViewBuilder
    func mediaListStyle(rowHeight: CGFloat? = nil, bottomMargin: CGFloat = Layout.Spacing.small) -> some View {
        if let rowHeight {
            listStyle(.plain)
                .safeAreaPadding(.bottom, bottomMargin)
            #if os(iOS)
                .environment(\.defaultMinListRowHeight, rowHeight + (Layout.Padding.medium * 2))
            #elseif os(macOS)
                .environment(\.defaultMinListRowHeight, rowHeight + (Layout.Padding.small * 2))
            #endif
        } else {
            listStyle(.plain)
                .safeAreaPadding(.bottom, bottomMargin)
        }
    }

    /// Applies consistent styling to individual media list rows.
    ///
    /// Hides the row separator and applies platform-specific insets. iOS uses
    /// larger horizontal and medium vertical padding, while macOS uses smaller
    /// padding on all sides.
    ///
    /// - Returns: A view with media row styling applied.
    @ViewBuilder
    func mediaRowStyle() -> some View {
        listRowSeparator(.hidden)
        #if os(iOS)
            .listRowInsets(.horizontal, Layout.Padding.large)
            .listRowInsets(.vertical, Layout.Padding.medium)
        #elseif os(macOS)
            .listRowInsets(.horizontal, Layout.Padding.small)
            .listRowInsets(.vertical, Layout.Padding.small)
        #endif
    }
}
