//
//  View+ScrollTarget.swift
//  swmpc
//
//  Created by Camille Scholtz on 05/09/2025.
//

import SwiftUI
import SwiftUIIntrospect

struct ScrollTarget: Equatable {
    let index: Int
    let animated: Bool
    let timestamp: Date = .init()
}

struct ScrollToItemModifier: ViewModifier {
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
    func scrollToItem(_ scrollTarget: Binding<ScrollTarget?>) -> some View {
        modifier(ScrollToItemModifier(scrollTarget: scrollTarget))
    }
}
