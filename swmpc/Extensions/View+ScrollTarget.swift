//
//  View+ScrollTarget.swift
//  swmpc
//
//  Created by Camille Scholtz on 05/09/2025.
//

import SwiftUI

/// Represents a scroll destination within a list.
///
/// Used with ``ScrollToItemModifier`` to programmatically scroll a list to a specific item.
/// The timestamp ensures each scroll request is treated as unique, even when scrolling
/// to the same item multiple times.
struct ScrollTarget: Equatable {
    /// The identifier of the item to scroll to.
    let id: String

    /// Whether to animate the scroll transition.
    let animated: Bool

    /// The time this scroll target was created, used to distinguish identical scroll requests.
    let timestamp: Date = .init()
}

/// A view modifier that enables programmatic scrolling to specific items in a list.
///
/// Uses a native `ScrollViewReader` to scroll the underlying list to a given item by
/// identifier, centering it vertically in the visible area.
struct ScrollToItemModifier: ViewModifier {
    /// Binding to the scroll target. Set this to trigger a scroll operation.
    @Binding var scrollTarget: ScrollTarget?

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: scrollTarget) { _, value in
                    guard let value else {
                        return
                    }

                    performScroll(to: value, using: proxy)
                }
        }
    }

    /// Executes the scroll operation to the specified target, centering it vertically.
    ///
    /// - Parameters:
    ///   - target: The scroll target containing the item identifier and animation preference.
    ///   - proxy: The scroll view proxy used to perform the scroll.
    private func performScroll(to target: ScrollTarget, using proxy: ScrollViewProxy) {
        if target.animated {
            withAnimation {
                proxy.scrollTo(target.id, anchor: .center)
            }
        } else {
            proxy.scrollTo(target.id, anchor: .center)
        }
    }
}

extension View {
    /// Enables programmatic scrolling to items in a list.
    ///
    /// Attach this modifier to a `List` view and control scrolling by setting the bound
    /// `ScrollTarget` value. The list will scroll to center the specified item.
    ///
    /// - Parameter scrollTarget: A binding to the scroll target. Set to a new `ScrollTarget`
    ///   to trigger scrolling, or `nil` to clear.
    /// - Returns: A view that responds to scroll target changes.
    func scrollToItem(_ scrollTarget: Binding<ScrollTarget?>) -> some View {
        modifier(ScrollToItemModifier(scrollTarget: scrollTarget))
    }
}
