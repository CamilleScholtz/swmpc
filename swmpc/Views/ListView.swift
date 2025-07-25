//
//  ListView.swift
//  swmpc
//
//  Created by Camille Scholtz on 24/07/2025.
//

import SwiftUI

struct ListView<Content: View>: View {
    let content: (ScrollViewProxy) -> Content
    let rowHeight: CGFloat?

    init(
        rowHeight: CGFloat? = nil,
        @ViewBuilder content: @escaping (ScrollViewProxy) -> Content
    ) {
        self.content = content
        self.rowHeight = rowHeight
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                content(proxy)
            }
            .listStyle(.plain)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaPadding(.bottom, 7.5)
            .contentMargins(.bottom, -7.5, for: .scrollIndicators)
            #if os(macOS)
                .environment(\.defaultMinListRowHeight, min(rowHeight ?? 50, 50))
            #endif
        }
    }
}
