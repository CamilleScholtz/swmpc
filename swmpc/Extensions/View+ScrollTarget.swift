//
//  View+ScrollTarget.swift
//  swmpc
//
//  Created by Camille Scholtz on 05/09/2025.
//

import SwiftUI
import SwiftUIIntrospect

/// Represents a scroll destination within a list.
///
/// Used with ``ScrollToItemModifier`` to programmatically scroll a list to a specific item.
/// The timestamp ensures each scroll request is treated as unique, even when scrolling
/// to the same index multiple times.
struct ScrollTarget: Equatable {
    /// The zero-based index of the item to scroll to.
    let index: Int

    /// Whether to animate the scroll transition.
    let animated: Bool

    /// The time this scroll target was created, used to distinguish identical scroll requests.
    let timestamp: Date = .init()
}

/// A view modifier that enables programmatic scrolling to specific items in a list.
///
/// Uses SwiftUIIntrospect to access the underlying platform-specific list implementation
/// (`UICollectionView` on iOS, `NSTableView` on macOS) and perform precise scroll operations.
/// Items are centered vertically in the visible area when scrolled to.
struct ScrollToItemModifier: ViewModifier {
    /// Binding to the scroll target. Set this to trigger a scroll operation.
    @Binding var scrollTarget: ScrollTarget?

    #if os(iOS)
        @State private var collectionView: UICollectionView?
    #elseif os(macOS)
        @State private var tableView: NSTableView?
    #endif

    func body(content: Content) -> some View {
        content
        #if os(iOS)
        .introspect(.list, on: .iOS(.v26)) { value in
            guard collectionView !== value else {
                return
            }

            DispatchQueue.main.async {
                collectionView = value
            }
        }
        .onChange(of: collectionView) {
            guard let scrollTarget else {
                return
            }

            performScroll(to: scrollTarget)
        }
        #elseif os(macOS)
        .introspect(.list, on: .macOS(.v26)) { value in
            guard tableView !== value else {
                return
            }

            DispatchQueue.main.async {
                tableView = value
            }
        }
        .onChange(of: tableView) {
            guard let scrollTarget else {
                return
            }

            performScroll(to: scrollTarget)
        }
        #endif
        .onChange(of: scrollTarget) { _, value in
            guard let value else {
                return
            }

            performScroll(to: value)
        }
    }

    /// Executes the scroll operation to the specified target.
    ///
    /// On iOS, scrolls the collection view to center the item vertically.
    /// On macOS, calculates the scroll position manually to center the row
    /// and optionally animates the transition.
    ///
    /// - Parameter target: The scroll target containing the index and animation preference.
    private func performScroll(to target: ScrollTarget) {
        #if os(iOS)
            guard let collectionView else {
                return
            }

            let indexPath = IndexPath(item: target.index, section: 0)
            guard indexPath.item < collectionView.numberOfItems(inSection: 0) else {
                return
            }

            collectionView.scrollToItem(
                at: indexPath,
                at: .centeredVertically,
                animated: target.animated,
            )
        #elseif os(macOS)
            guard let tableView,
                  let scrollView = tableView.enclosingScrollView
            else {
                return
            }

            guard target.index < tableView.numberOfRows else {
                return
            }

            let rowRect = tableView.rect(ofRow: target.index)
            let visibleHeight = scrollView.contentView.bounds.height
            let targetY = rowRect.midY - visibleHeight / 2

            let maxY = tableView.bounds.height - visibleHeight
            let clampedY = max(0, min(targetY, maxY))

            let targetPoint = NSPoint(x: 0, y: clampedY)

            if target.animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.allowsImplicitAnimation = true
                    scrollView.contentView.setBoundsOrigin(targetPoint)
                }
            } else {
                scrollView.contentView.setBoundsOrigin(targetPoint)
            }
        #endif
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
