//
//  View+ScrollMemory.swift
//  swmpc
//
//  Created by Camille Scholtz on 05/07/2026.
//

import MPDKit
import SwiftUI

/// A view modifier that remembers the scroll position of a media list.
///
/// Records the scroll offset into the navigation manager whenever the user
/// scrolls the list, so the position can be restored when returning to the
/// category. Offset changes shortly after a programmatic scroll are
/// attributed to that scroll and ignored, keeping categories the user never
/// scrolled in the default focus-on-current-media behavior.
struct ScrollMemoryModifier: ViewModifier {
    @Environment(NavigationManager.self) private var navigator

    /// The category to remember the scroll position for.
    let category: CategoryDestination

    /// The last programmatic scroll target, used to distinguish user scrolls
    /// from programmatic ones.
    let scrollTarget: ScrollTarget?

    /// Whether scroll changes are currently recorded. Set to `false` while
    /// the list shows temporary content, such as search results.
    let isActive: Bool

    /// How long after a programmatic scroll offset changes are still
    /// attributed to it rather than to the user.
    private static let settleInterval: TimeInterval = 0.8

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { oldOffset, newOffset in
                guard isActive, oldOffset != newOffset else {
                    return
                }

                let lastProgrammaticScroll = scrollTarget?.timestamp ?? .distantPast
                guard Date().timeIntervalSince(lastProgrammaticScroll) > Self.settleInterval else {
                    return
                }

                navigator.recordScrollOffset(newOffset, for: category)
            }
    }
}

extension View {
    /// Remembers the user's scroll position in the list within this view.
    ///
    /// - Parameters:
    ///   - category: The category to remember the scroll position for.
    ///   - scrollTarget: The last programmatic scroll target of the list,
    ///                   used to distinguish user scrolls from programmatic
    ///                   ones.
    ///   - isActive: Whether scroll changes are recorded. Pass `false` while
    ///               the list shows temporary content, such as search
    ///               results. Defaults to `true`.
    /// - Returns: A view that records the user's scroll position.
    func scrollMemory(for category: CategoryDestination, scrollTarget: ScrollTarget?, isActive: Bool = true) -> some View {
        modifier(ScrollMemoryModifier(category: category, scrollTarget: scrollTarget, isActive: isActive))
    }
}

extension ScrollTarget {
    /// Creates a target that restores a remembered scroll offset, snapping
    /// to the nearest row.
    ///
    /// - Parameters:
    ///   - offset: The remembered scroll offset, measured from the top of
    ///             the content.
    ///   - media: The media items shown in the list.
    ///   - rowContentHeight: The height of the row content (excluding
    ///                       padding).
    init?(restoring offset: CGFloat, in media: [any Mediable], rowContentHeight: CGFloat) {
        guard !media.isEmpty else {
            return nil
        }

        let index = Int((offset / Layout.RowHeight.effective(for: rowContentHeight)).rounded())

        self.init(id: media[min(max(0, index), media.count - 1)].id, animated: false, anchor: .top)
    }
}
