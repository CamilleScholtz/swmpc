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
                .contentMargins(.bottom, bottomMargin)
                .environment(\.defaultMinListRowHeight, rowHeight)
        } else {
            listStyle(.plain)
                .contentMargins(.bottom, bottomMargin)
        }
    }

    @ViewBuilder
    func mediaRowStyle() -> some View {
        listRowSeparator(.hidden)
            .listRowInsets(.horizontal, Layout.Padding.small)
            .listRowInsets(.vertical, Layout.Padding.small)
    }
}
