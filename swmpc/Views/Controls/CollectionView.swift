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

#if os(macOS)
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
            context.coordinator.update(view: self)
            handleScrollToItem(coordinator: context.coordinator)
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
            handleScrollToItem(coordinator: context.coordinator)
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

        Task { @MainActor in
            self.scrollTo = nil
        }
    }

    #if os(macOS)
        final class Coordinator: NSObject, NSCollectionViewDelegateFlowLayout {
            let collectionView: NSCollectionView
            var content: (Data.Element) -> Content
            var rowHeight: CGFloat?
            var contentMargin: EdgeInsets?
            var dataSource: NSCollectionViewDiffableDataSource<Int, Data.Element>!
            
            private let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")
            private var currentDataOrder: [Data.Element.ID] = []
            private lazy var sizingView = NSHostingView(rootView: AnyView(EmptyView()))
            private var sizeCache: [Data.Element.ID: NSSize] = [:]

            init(data: Data, content: @escaping (Data.Element) -> Content, rowHeight: CGFloat?, contentMargin: EdgeInsets?) {
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
                        right: contentMargin.trailing
                    )
                }
                
                collectionView = NSCollectionView()
                collectionView.collectionViewLayout = layout
                
                super.init()
                
                collectionView.register(HostingCollectionViewItem.self, forItemWithIdentifier: cellIdentifier)
                collectionView.delegate = self
                
                setupDataSource()
                updateData(data)
            }

            func update(view: CollectionView) {
                content = view.content
                rowHeight = view.rowHeight
                contentMargin = view.contentMargin
                
                // Clear cache if content closure changes
                sizeCache.removeAll()
                
                updateData(view.data)
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

            private func updateData(_ data: Data) {
                let newIdentifiers = data.map(\.id)
                guard newIdentifiers != currentDataOrder else { return }
                
                var snapshot = NSDiffableDataSourceSnapshot<Int, Data.Element>()
                snapshot.appendSections([0])
                snapshot.appendItems(Array(data))
                dataSource.apply(snapshot, animatingDifferences: false)
                currentDataOrder = newIdentifiers
            }

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
                let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
                let width = max(100, collectionView.bounds.width - horizontalMargins)
                
                if let fixedHeight = rowHeight {
                    return NSSize(width: width, height: fixedHeight)
                }
                
                guard let item = dataSource.itemIdentifier(for: indexPath) else {
                    return .zero
                }
                
                // Check cache first
                if let cachedSize = sizeCache[item.id] {
                    return cachedSize
                }
                
                // Update the reusable sizing view with new content
                let contentView = AnyView(
                    content(item)
                        .frame(width: width)
                        .fixedSize(horizontal: false, vertical: true)
                )
                
                sizingView.rootView = contentView
                let size = NSSize(width: width, height: sizingView.fittingSize.height)
                
                // Cache the calculated size
                sizeCache[item.id] = size
                
                return size
            }
        }

    #elseif os(iOS)
        final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
            let collectionView: UICollectionView
            var content: (Data.Element) -> Content
            var rowHeight: CGFloat?
            var contentMargin: EdgeInsets?
            var dataSource: UICollectionViewDiffableDataSource<Int, Data.Element>!
            
            private let collectionWidth: CGFloat
            private var currentDataOrder: [Data.Element.ID] = []

            init(data: Data, content: @escaping (Data.Element) -> Content, rowHeight: CGFloat?, contentMargin: EdgeInsets?) {
                self.content = content
                self.rowHeight = rowHeight
                self.contentMargin = contentMargin
                
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
                        right: contentMargin.trailing
                    )
                }
                
                collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
                collectionView.backgroundColor = .clear
                
                let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
                collectionWidth = UIScreen.main.bounds.width - horizontalMargins
                
                super.init()
                
                collectionView.delegate = self
                setupDataSource()
                updateData(data)
            }

            func update(view: CollectionView) {
                content = view.content
                rowHeight = view.rowHeight
                contentMargin = view.contentMargin
                updateData(view.data)
            }

            private func setupDataSource() {
                let cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Data.Element> { [weak self] cell, _, item in
                    guard let self else { return }
                    
                    cell.contentConfiguration = UIHostingConfiguration {
                        AnyView(self.content(item))
                    }
                    .margins(.all, 0)
                    .background(.clear)
                }
                
                dataSource = UICollectionViewDiffableDataSource<Int, Data.Element>(collectionView: collectionView) { collectionView, indexPath, item in
                    collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
                }
            }

            private func updateData(_ data: Data) {
                let newIdentifiers = data.map(\.id)
                guard newIdentifiers != currentDataOrder else { return }
                
                var snapshot = NSDiffableDataSourceSnapshot<Int, Data.Element>()
                snapshot.appendSections([0])
                snapshot.appendItems(Array(data))
                dataSource.apply(snapshot, animatingDifferences: false)
                currentDataOrder = newIdentifiers
            }

            func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
                guard let fixedHeight = rowHeight else {
                    return UICollectionViewFlowLayout.automaticSize
                }
                
                return CGSize(width: collectionWidth, height: fixedHeight)
            }
        }
    #endif
}