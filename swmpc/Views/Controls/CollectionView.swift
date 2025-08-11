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
    final class HostingCollectionViewCell: UICollectionViewCell {
        override func updateConfiguration(using state: UICellConfigurationState) {
            super.updateConfiguration(using: state)
        }
    }

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
    where Data.Element: Identifiable & Hashable
{
    let data: Data
    let rowHeight: CGFloat?
    let contentMargin: EdgeInsets?

    @Binding var scrollTo: Data.Element.ID?
    var animated: Bool = false

    @ViewBuilder let content: (Data.Element) -> Content

    func scrollAnimation(_ animated: Bool) -> CollectionView {
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

        DispatchQueue.main.async {
            scrollTo = nil
        }
    }

    // Shared base coordinator logic
    class BaseCoordinator: NSObject {
        var content: (Data.Element) -> Content
        var rowHeight: CGFloat?
        var contentMargin: EdgeInsets?
        var currentDataIdentifiers: [Data.Element.ID] = []

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
            // Check if data has actually changed
            let dataChanged = data.count != currentDataIdentifiers.count ||
                !data.lazy.map(\.id).elementsEqual(currentDataIdentifiers)

            guard dataChanged else { return }

            applySnapshot(data)
            currentDataIdentifiers = data.map(\.id)
        }

        // To be overridden by platform-specific subclasses
        func applySnapshot(_: Data) {
            fatalError("Must be overridden")
        }

        func calculateItemWidth(for bounds: CGSize) -> CGFloat {
            let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
            return bounds.width - horizontalMargins
        }
    }

    #if os(macOS)
        final class Coordinator: BaseCoordinator, NSCollectionViewDelegateFlowLayout {
            let collectionView: NSCollectionView
            private var dataSource: NSCollectionViewDiffableDataSource<Int, Data.Element>!
            private let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")
            private lazy var sizingView = NSHostingView(rootView: AnyView(EmptyView()))
            private var sizeCache: [Data.Element.ID: NSSize] = [:]

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
                    let cell = collectionView.makeItem(withIdentifier: self?.cellIdentifier ?? NSUserInterfaceItemIdentifier("Cell"), for: indexPath) as! HostingCollectionViewItem
                    if let self {
                        cell.updateContent(AnyView(content(item)))
                    }
                    return cell
                }
            }

            override func applySnapshot(_ data: Data) {
                var snapshot = NSDiffableDataSourceSnapshot<Int, Data.Element>()
                snapshot.appendSections([0])
                snapshot.appendItems(Array(data))
                dataSource.apply(snapshot, animatingDifferences: false)
            }

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
                guard let item = dataSource.itemIdentifier(for: indexPath) else {
                    return .zero
                }

                let width = calculateItemWidth(for: collectionView.bounds.size)

                if let fixedHeight = rowHeight {
                    return NSSize(width: width, height: fixedHeight)
                }

                return calculateDynamicSize(for: item, width: width)
            }

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, shouldInvalidateLayoutForBoundsChange newBounds: NSRect) -> Bool {
                let widthChanged = collectionView.bounds.width != newBounds.width
                if widthChanged {
                    sizeCache.removeAll()
                }
                return widthChanged
            }

            private func calculateDynamicSize(for element: Data.Element, width: CGFloat) -> NSSize {
                let elementID = element.id

                if let cachedSize = sizeCache[elementID], cachedSize.width == width {
                    return cachedSize
                }

                let contentView = AnyView(
                    content(element)
                        .frame(width: width),
                )

                sizingView.rootView = contentView
                let size = NSSize(width: width, height: sizingView.fittingSize.height)
                sizeCache[elementID] = size

                return size
            }
        }

    #elseif os(iOS)
        final class Coordinator: BaseCoordinator, UICollectionViewDelegateFlowLayout {
            let collectionView: UICollectionView
            private var dataSource: UICollectionViewDiffableDataSource<Int, Data.Element>!
            private let cellRegistration: UICollectionView.CellRegistration<HostingCollectionViewCell, Data.Element>

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

                cellRegistration = UICollectionView.CellRegistration<HostingCollectionViewCell, Data.Element> { [weak content] cell, _, item in
                    guard let content else { return }
                    cell.contentConfiguration = UIHostingConfiguration {
                        AnyView(content(item))
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
                    return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
                }
            }

            override func applySnapshot(_ data: Data) {
                var snapshot = NSDiffableDataSourceSnapshot<Int, Data.Element>()
                snapshot.appendSections([0])
                snapshot.appendItems(Array(data))
                dataSource.apply(snapshot, animatingDifferences: false)
            }

            func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
                guard let fixedHeight = rowHeight else {
                    return UICollectionViewFlowLayout.automaticSize
                }

                let width = calculateItemWidth(for: collectionView.bounds.size)
                return CGSize(width: width, height: fixedHeight)
            }
        }
    #endif
}
