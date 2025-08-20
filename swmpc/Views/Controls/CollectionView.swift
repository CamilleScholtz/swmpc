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

protocol CollectionViewCoordinator: AnyObject {
    associatedtype DataElement: Identifiable & Hashable & Sendable
    associatedtype ContentView: View

    var content: (DataElement) -> ContentView { get set }
    var rowHeight: CGFloat { get set }
    var contentMargin: EdgeInsets? { get set }

    func update<Data: RandomAccessCollection>(view: CollectionView<Data, ContentView>) where Data.Element == DataElement
    func updateData<Data: RandomAccessCollection>(_ data: Data) where Data.Element == DataElement
}

#if os(macOS)
    final class HostingCollectionViewItem<Content: View>: NSCollectionViewItem {
        private var hostingView: NSHostingView<Content>?

        override func loadView() {
            view = NSView()
        }

        func updateContent(_ content: Content) {
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

                // TODO: I don't know if this actually brings performance benefits.
//                view.wantsLayer = true
//                if let layer = view.layer {
//                    layer.shouldRasterize = true
//                    layer.rasterizationScale = view.window?.backingScaleFactor ?? 2.0
//                }
            }
        }
    }
#endif

struct CollectionView<Data: RandomAccessCollection, Content: View>: PlatformViewRepresentable
    where Data.Element: Identifiable & Hashable & Sendable
{
    let data: Data
    let rowHeight: CGFloat
    private var contentMargin: EdgeInsets?
    private var scrollToBinding: Binding<Data.Element.ID?>?
    var animated: Bool = false
    @ViewBuilder let content: (Data.Element) -> Content

    init(
        data: Data,
        rowHeight: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content,
    ) {
        self.data = data
        self.rowHeight = rowHeight
        contentMargin = nil
        scrollToBinding = nil
        self.content = content
    }

    func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat) -> Self {
        var view = self
        var newMargins = view.contentMargin ?? EdgeInsets()

        if edges.contains(.top) {
            newMargins.top = length
        }
        if edges.contains(.bottom) {
            newMargins.bottom = length
        }
        if edges.contains(.leading) {
            newMargins.leading = length
        }
        if edges.contains(.trailing) {
            newMargins.trailing = length
        }

        view.contentMargin = newMargins
        return view
    }

    func scrollTo(_ binding: Binding<Data.Element.ID?>, animated: Bool = false) -> Self {
        var view = self
        view.scrollToBinding = binding
        view.animated = animated
        return view
    }

    private var scrollTo: Data.Element.ID? {
        scrollToBinding?.wrappedValue
    }

    private func resetScrollTo() {
        scrollToBinding?.wrappedValue = nil
    }

    #if os(iOS)
        func makeUIView(context: Context) -> UICollectionView {
            context.coordinator.collectionView
        }

        func updateUIView(_: UICollectionView, context: Context) {
            context.coordinator.update(view: self)
            if scrollTo != nil {
                handleScrollToItem(coordinator: context.coordinator)
                // Reset after initiating scroll, deferred to avoid modifying state during view update
                Task { @MainActor in
                    resetScrollTo()
                }
            }
        }

    #elseif os(macOS)
        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.documentView = context.coordinator.collectionView
            return scrollView
        }

        func updateNSView(_: NSScrollView, context: Context) {
            context.coordinator.update(view: self)
            if scrollTo != nil {
                handleScrollToItem(coordinator: context.coordinator)

                Task { @MainActor in
                    resetScrollTo()
                }
            }
        }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(data: data, content: content, rowHeight: rowHeight, contentMargin: contentMargin)
    }

    private func handleScrollToItem(coordinator: Coordinator) {
        guard let id = scrollTo,
              let index = data.firstIndex(where: { $0.id == id })
        else {
            return
        }

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
    }

    #if os(macOS)
        final class Coordinator: NSObject, NSCollectionViewDelegateFlowLayout, CollectionViewCoordinator {
            let collectionView: NSCollectionView
            var content: (Data.Element) -> Content
            var rowHeight: CGFloat
            var contentMargin: EdgeInsets?
            var dataSource: NSCollectionViewDiffableDataSource<Int, Data.Element>!

            private let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")
            private var currentDataOrder: [Data.Element.ID] = []

            init(data: Data, content: @escaping (Data.Element) -> Content, rowHeight: CGFloat, contentMargin: EdgeInsets?) {
                self.content = content
                self.rowHeight = rowHeight
                self.contentMargin = contentMargin

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

                super.init()

                collectionView.register(HostingCollectionViewItem<Content>.self, forItemWithIdentifier: cellIdentifier)
                collectionView.delegate = self

                setupDataSource()
                updateData(data)
            }

            func update<ViewData: RandomAccessCollection>(view: CollectionView<ViewData, Content>) where ViewData.Element == Data.Element {
                content = view.content
                rowHeight = view.rowHeight
                contentMargin = view.contentMargin

                updateData(view.data)
            }

            private func setupDataSource() {
                dataSource = NSCollectionViewDiffableDataSource<Int, Data.Element>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
                    guard let self else { return nil }

                    let cell = collectionView.makeItem(withIdentifier: cellIdentifier, for: indexPath) as! HostingCollectionViewItem<Content>
                    let contentView = content(item)
                    cell.updateContent(contentView)

                    return cell
                }
            }

            func updateData<ViewData: RandomAccessCollection>(_ data: ViewData) where ViewData.Element == Data.Element {
                let newIdentifiers = data.map(\.id)
                guard newIdentifiers != currentDataOrder else { return }

                var snapshot = NSDiffableDataSourceSnapshot<Int, Data.Element>()
                snapshot.appendSections([0])
                snapshot.appendItems(Array(data))
                dataSource.apply(snapshot, animatingDifferences: false)
                currentDataOrder = newIdentifiers
            }

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt _: IndexPath) -> NSSize {
                let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
                let width = collectionView.bounds.width - horizontalMargins
                return NSSize(width: width, height: rowHeight)
            }
        }

    #elseif os(iOS)
        final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout, CollectionViewCoordinator {
            let collectionView: UICollectionView
            var content: (Data.Element) -> Content
            var rowHeight: CGFloat
            var contentMargin: EdgeInsets?
            var dataSource: UICollectionViewDiffableDataSource<Int, Data.Element>!

            private var currentDataOrder: [Data.Element.ID] = []

            init(data: Data, content: @escaping (Data.Element) -> Content, rowHeight: CGFloat, contentMargin: EdgeInsets?) {
                self.content = content
                self.rowHeight = rowHeight
                self.contentMargin = contentMargin

                let layout = UICollectionViewFlowLayout()
                layout.minimumLineSpacing = 0
                layout.minimumInteritemSpacing = 0

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

                super.init()

                collectionView.delegate = self
                setupDataSource()
                updateData(data)
            }

            func update<ViewData: RandomAccessCollection>(view: CollectionView<ViewData, Content>) where ViewData.Element == Data.Element {
                content = view.content
                rowHeight = view.rowHeight
                contentMargin = view.contentMargin
                updateData(view.data)
            }

            private func setupDataSource() {
                let cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Data.Element> { [weak self] cell, _, item in
                    guard let self else {
                        return
                    }

                    cell.contentConfiguration = UIHostingConfiguration {
                        self.content(item)
                    }
                    .margins(.all, 0)
                    .background(.clear)

                    cell.layer.shouldRasterize = true
                    cell.layer.rasterizationScale = cell.traitCollection.displayScale
                }

                dataSource = UICollectionViewDiffableDataSource<Int, Data.Element>(collectionView: collectionView) { collectionView, indexPath, item in
                    collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
                }
            }

            func updateData<ViewData: RandomAccessCollection>(_ data: ViewData) where ViewData.Element == Data.Element {
                let newIdentifiers = data.map(\.id)
                guard newIdentifiers != currentDataOrder else {
                    return
                }

                var snapshot = NSDiffableDataSourceSnapshot<Int, Data.Element>()
                snapshot.appendSections([0])
                snapshot.appendItems(Array(data))
                dataSource.apply(snapshot, animatingDifferences: false)
                currentDataOrder = newIdentifiers
            }

            func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
                let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
                let itemWidth = collectionView.bounds.width - horizontalMargins

                return CGSize(width: itemWidth, height: rowHeight)
            }
        }
    #endif
}
