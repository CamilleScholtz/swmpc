//
//  View+MediaList.swift
//  swmpc
//
//  Created by Camille Scholtz on 05/09/2025.
//

import SwiftUI

extension View {
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
