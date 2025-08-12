//
//  CollectionView.swift
//  swmpc
//
//  Created by Camille Scholtz on 06/08/2025.
//

import SwiftUI
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

#if os(iOS)
    typealias PlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
    typealias PlatformViewRepresentable = NSViewRepresentable
#endif

#if os(iOS)
    final class HostingCollectionViewCell: UICollectionViewCell {}

#elseif os(macOS)
    final class HostingCollectionViewItem: NSCollectionViewItem {
        private var hostingView: NSHostingView<AnyView>?

        override func loadView() {
            view = NSView()
        }

        func updateContent(_ content: AnyView) {
            if let hostingView {
                hostingView.rootView = content
            } else {
                let hosting = NSHostingView(rootView: content)
                hosting.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(hosting)
                NSLayoutConstraint.activate([
                    hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    hosting.topAnchor.constraint(equalTo: view.topAnchor),
                    hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])
                hostingView = hosting
            }
        }
    }
#endif

struct CollectionView<Data: RandomAccessCollection, Content: View>: PlatformViewRepresentable
    where Data.Element: Identifiable & Hashable & Sendable
{
    let data: Data
    let rowHeight: CGFloat?
    let contentMargin: EdgeInsets?

    @Binding var scrollTo: Data.Element.ID?
    var animated: Bool = false

    @ViewBuilder let content: (Data.Element) -> Content

    func scrollAnimation(_ animated: Bool) -> Self {
        var view = self
        view.animated = animated
        return view
    }

    #if os(iOS)
        func makeUIView(context: Context) -> UICollectionView {
            context.coordinator.collectionView
        }

        func updateUIView(_: UICollectionView, context: Context) {
            updateCoordinator(context.coordinator)
        }

    #elseif os(macOS)
        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.documentView = context.coordinator.collectionView
            return scrollView
        }

        func updateNSView(_: NSScrollView, context: Context) {
            updateCoordinator(context.coordinator)
        }
    #endif

    private func updateCoordinator(_ coordinator: Coordinator) {
        coordinator.update(view: self)
        handleScrollToItem(coordinator: coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(data: data, content: content, rowHeight: rowHeight, contentMargin: contentMargin)
    }

    private func handleScrollToItem(coordinator: Coordinator) {
        guard let id = scrollTo,
              let index = data.firstIndex(where: { $0.id == id }) else { return }

        let indexPath = IndexPath(item: data.distance(from: data.startIndex, to: index), section: 0)

        #if os(macOS)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.allowsImplicitAnimation = true
                    coordinator.collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredVertically)
                }
            } else {
                coordinator.collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredVertically)
            }
        #elseif os(iOS)
            coordinator.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: animated)
        #endif

        Task { @MainActor in
            self.scrollTo = nil
        }
    }

    // Shared base coordinator logic
    class BaseCoordinator: NSObject {
        var content: (Data.Element) -> Content
        var rowHeight: CGFloat?
        var contentMargin: EdgeInsets?
        private var currentDataOrder: [Data.Element.ID] = []

        #if os(iOS)
            var dataSource: UICollectionViewDiffableDataSource<Int, Data.Element>!
        #elseif os(macOS)
            var dataSource: NSCollectionViewDiffableDataSource<Int, Data.Element>!
        #endif

        init(content: @escaping (Data.Element) -> Content, rowHeight: CGFloat?, contentMargin: EdgeInsets?) {
            self.content = content
            self.rowHeight = rowHeight
            self.contentMargin = contentMargin
            super.init()
        }

        func update(view: CollectionView) {
            content = view.content
            rowHeight = view.rowHeight
            contentMargin = view.contentMargin
            updateData(view.data)
        }

        func updateData(_ data: Data) {
            let newIdentifiers = data.map(\.id)
            
            // Only compare ordered list
            guard newIdentifiers != currentDataOrder else { return }

            applySnapshot(data)
            currentDataOrder = newIdentifiers
        }

        func applySnapshot(_ data: Data) {
            guard !data.isEmpty else { return }
            
            #if os(iOS)
                var snapshot = NSDiffableDataSourceSnapshot<Int, Data.Element>()
            #elseif os(macOS)
                var snapshot = NSDiffableDataSourceSnapshot<Int, Data.Element>()
            #endif
            snapshot.appendSections([0])
            snapshot.appendItems(Array(data))
            dataSource.apply(snapshot, animatingDifferences: false)
        }

    }

    #if os(macOS)
        final class Coordinator: BaseCoordinator, NSCollectionViewDelegateFlowLayout {
            let collectionView: NSCollectionView
            private let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")
            private lazy var sizingView = NSHostingView(rootView: AnyView(EmptyView()))
            private var sizeCache: [Data.Element.ID: NSSize] = [:]
            private var hostingViewPool: [NSHostingView<AnyView>] = []
            private let maxPoolSize = 10

            init(data: Data, content: @escaping (Data.Element) -> Content, rowHeight: CGFloat?, contentMargin: EdgeInsets?) {
                let layout = NSCollectionViewFlowLayout()
                layout.minimumLineSpacing = 0
                layout.minimumInteritemSpacing = 0
                if let contentMargin {
                    layout.sectionInset = NSEdgeInsets(
                        top: contentMargin.top,
                        left: contentMargin.leading,
                        bottom: contentMargin.bottom,
                        right: contentMargin.trailing,
                    )
                }

                collectionView = NSCollectionView()
                collectionView.collectionViewLayout = layout

                super.init(content: content, rowHeight: rowHeight, contentMargin: contentMargin)

                collectionView.register(HostingCollectionViewItem.self, forItemWithIdentifier: cellIdentifier)
                collectionView.delegate = self

                setupDataSource()
                updateData(data)
            }

            private func setupDataSource() {
                dataSource = NSCollectionViewDiffableDataSource<Int, Data.Element>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
                    guard let self else { return nil }
                    let cell = collectionView.makeItem(withIdentifier: self.cellIdentifier, for: indexPath) as! HostingCollectionViewItem
                    let contentView = AnyView(self.content(item))
                    cell.updateContent(contentView)
                    return cell
                }
            }
            
            private func getHostingView() -> NSHostingView<AnyView> {
                if let view = hostingViewPool.popLast() {
                    return view
                }
                return NSHostingView(rootView: AnyView(EmptyView()))
            }
            
            private func returnHostingView(_ view: NSHostingView<AnyView>) {
                if hostingViewPool.count < maxPoolSize {
                    hostingViewPool.append(view)
                }
            }

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
                guard let item = dataSource.itemIdentifier(for: indexPath) else {
                    return .zero
                }
                
                let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
                let width = max(100, collectionView.bounds.width - horizontalMargins)

                if let fixedHeight = rowHeight {
                    return NSSize(width: width, height: fixedHeight)
                }

                return calculateDynamicSize(for: item, width: width)
            }

            // Removed shouldInvalidateLayoutForBoundsChange since width is now constant

            private func calculateDynamicSize(for element: Data.Element, width: CGFloat) -> NSSize {
                if let cachedSize = sizeCache[element.id] {
                    return cachedSize
                }

                let contentView = AnyView(
                    content(element)
                        .frame(width: width)
                )

                sizingView.rootView = contentView
                let size = NSSize(width: width, height: sizingView.fittingSize.height)
                sizeCache[element.id] = size

                return size
            }
        }

    #elseif os(iOS)
        final class Coordinator: BaseCoordinator, UICollectionViewDelegateFlowLayout {
            let collectionView: UICollectionView
            private let cellRegistration: UICollectionView.CellRegistration<HostingCollectionViewCell, Data.Element>
            private let collectionWidth: CGFloat

            init(data: Data, content: @escaping (Data.Element) -> Content, rowHeight: CGFloat?, contentMargin: EdgeInsets?) {
                let layout = UICollectionViewFlowLayout()
                layout.minimumLineSpacing = 0
                layout.minimumInteritemSpacing = 0

                if rowHeight == nil {
                    layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
                }

                if let contentMargin {
                    layout.sectionInset = UIEdgeInsets(
                        top: contentMargin.top,
                        left: contentMargin.leading,
                        bottom: contentMargin.bottom,
                        right: contentMargin.trailing,
                    )
                }

                collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
                collectionView.backgroundColor = .clear
                
                // Calculate width once
                let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
                collectionWidth = UIScreen.main.bounds.width - horizontalMargins

                cellRegistration = UICollectionView.CellRegistration<HostingCollectionViewCell, Data.Element> { [weak self] cell, _, item in
                    guard let self else { return }
                    cell.contentConfiguration = UIHostingConfiguration {
                        AnyView(self.content(item))
                    }
                    .margins(.all, 0)
                    .background(.clear)
                }

                super.init(content: content, rowHeight: rowHeight, contentMargin: contentMargin)

                collectionView.delegate = self
                setupDataSource()
                updateData(data)
            }

            private func setupDataSource() {
                dataSource = UICollectionViewDiffableDataSource<Int, Data.Element>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
                    guard let self else { return nil }
                    return collectionView.dequeueConfiguredReusableCell(using: self.cellRegistration, for: indexPath, item: item)
                }
            }

            func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
                guard let fixedHeight = rowHeight else {
                    return UICollectionViewFlowLayout.automaticSize
                }

                return CGSize(width: collectionWidth, height: fixedHeight)
            }
            // Removed shouldInvalidateLayoutForBoundsChange since width is now constant
        }
    #endif
}
