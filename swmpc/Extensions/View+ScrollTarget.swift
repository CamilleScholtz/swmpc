//
//  View+ScrollTarget.swift
//  swmpc
//
//  Created by Camille Scholtz on 05/09/2025.
//

import SwiftUI

struct ScrollTarget: Equatable {
    let id: String
    let animated: Bool
    let timestamp: Date = .init()
}

struct ScrollToItemModifier: ViewModifier {
    @Binding var scrollTarget: ScrollTarget?

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: scrollTarget) { _, value in
                    guard let value else {
                        return
                    }

                    if value.animated {
                        withAnimation {
                            proxy.scrollTo(value.id, anchor: .center)
                        }
                    } else {
                        proxy.scrollTo(value.id, anchor: .center)
                    }
                }
        }
    }
}

extension View {
    func scrollToItem(_ scrollTarget: Binding<ScrollTarget?>) -> some View {
        modifier(ScrollToItemModifier(scrollTarget: scrollTarget))
    }
}
