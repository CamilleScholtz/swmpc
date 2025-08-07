//
//  CollectionView.swift
//  swmpc
//
//  Created by Camille Scholtz on 06/08/2025.
//

import SwiftUI
#if os(macOS)
    import AppKit
    typealias PlatformViewRepresentable = NSViewRepresentable
#elseif os(iOS)
    import UIKit
    typealias PlatformViewRepresentable = UIViewRepresentable
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
#elseif os(iOS)
    final class HostingCollectionViewCell: UICollectionViewCell {
        private var hostingController: UIHostingController<AnyView>?

        func updateContent(_ content: AnyView) {
            if let hostingController {
                hostingController.rootView = content
            } else {
                let hosting = UIHostingController(rootView: content)
                hosting.view.translatesAutoresizingMaskIntoConstraints = false
                hosting.view.backgroundColor = .clear
                contentView.addSubview(hosting.view)
                NSLayoutConstraint.activate([
                    hosting.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                    hosting.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                    hosting.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                    hosting.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                ])
                hostingController = hosting
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
    @ViewBuilder let content: (Data.Element) -> Content

    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    #if os(macOS)
        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.documentView = context.coordinator.collectionView
            return scrollView
        }

        func updateNSView(_: NSScrollView, context: Context) {
            updateCoordinator(context.coordinator)
        }
    #elseif os(iOS)
        func makeUIView(context: Context) -> UICollectionView {
            context.coordinator.collectionView
        }

        func updateUIView(_: UICollectionView, context: Context) {
            updateCoordinator(context.coordinator)
        }
    #endif
    
    private func updateCoordinator(_ coordinator: Coordinator) {
        let hasDataChanged = !coordinator.data.elementsEqual(data) { $0.id == $1.id }
        
        coordinator.data = data
        coordinator.content = content
        coordinator.mpd = mpd
        coordinator.navigator = navigator
        coordinator.rowHeight = rowHeight
        coordinator.contentMargin = contentMargin
        
        if hasDataChanged {
            coordinator.collectionView.reloadData()
        }
        
        handleScrollToItem(coordinator: coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(data: data, content: content, mpd: mpd, navigator: navigator, rowHeight: rowHeight, contentMargin: contentMargin)
    }

    private func handleScrollToItem(coordinator: Coordinator) {
        guard let id = scrollTo,
              let index = data.firstIndex(where: { $0.id == id }) else { return }

        let indexPath = IndexPath(item: data.distance(from: data.startIndex, to: index), section: 0)

        #if os(macOS)
            coordinator.collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredVertically)
        #elseif os(iOS)
            coordinator.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        #endif

        DispatchQueue.main.async {
            scrollTo = nil
        }
    }

    #if os(macOS)
        final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
            var data: Data
            var content: (Data.Element) -> Content
            var mpd: MPD
            var navigator: NavigationManager
            let collectionView: NSCollectionView
            var rowHeight: CGFloat?
            var contentMargin: EdgeInsets?
            
            private var sizeCache: [Data.Element.ID: NSSize] = [:]
            private let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")

            init(data: Data, content: @escaping (Data.Element) -> Content, mpd: MPD, navigator: NavigationManager, rowHeight: CGFloat?, contentMargin: EdgeInsets?) {
                self.data = data
                self.content = content
                self.mpd = mpd
                self.navigator = navigator
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
                collectionView.dataSource = self
                collectionView.delegate = self
            }

            func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
                data.count
            }

            func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
                let item = collectionView.makeItem(withIdentifier: cellIdentifier, for: indexPath) as! HostingCollectionViewItem
                let element = elementAt(indexPath)
                
                item.updateContent(AnyView(
                    content(element)
                        .environment(mpd)
                        .environment(navigator)
                ))
                return item
            }

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
                let width = calculateItemWidth(for: collectionView)
                
                if let fixedHeight = rowHeight {
                    return NSSize(width: width, height: fixedHeight)
                }
                
                return calculateDynamicSize(for: elementAt(indexPath), width: width)
            }

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, shouldInvalidateLayoutForBoundsChange newBounds: NSRect) -> Bool {
                guard collectionView.bounds.width != newBounds.width else { return false }
                sizeCache.removeAll()
                return true
            }
            
            private func elementAt(_ indexPath: IndexPath) -> Data.Element {
                data[data.index(data.startIndex, offsetBy: indexPath.item)]
            }
            
            private func calculateItemWidth(for collectionView: NSCollectionView) -> CGFloat {
                let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
                return collectionView.bounds.width - horizontalMargins
            }
            
            private func calculateDynamicSize(for element: Data.Element, width: CGFloat) -> NSSize {
                let elementID = element.id
                
                if let cachedSize = sizeCache[elementID], cachedSize.width == width {
                    return cachedSize
                }
                
                let contentView = content(element)
                    .environment(mpd)
                    .environment(navigator)
                    .frame(width: width)
                
                let hostingView = NSHostingView(rootView: contentView)
                let size = NSSize(width: width, height: hostingView.fittingSize.height)
                sizeCache[elementID] = size
                
                return size
            }
        }

    #elseif os(iOS)
        final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
            var data: Data
            var content: (Data.Element) -> Content
            var mpd: MPD
            var navigator: NavigationManager
            let collectionView: UICollectionView
            var rowHeight: CGFloat?
            var contentMargin: EdgeInsets?
            
            private var sizeCache: [Data.Element.ID: CGSize] = [:]
            private let cellIdentifier = String(describing: HostingCollectionViewCell.self)

            init(data: Data, content: @escaping (Data.Element) -> Content, mpd: MPD, navigator: NavigationManager, rowHeight: CGFloat?, contentMargin: EdgeInsets?) {
                self.data = data
                self.content = content
                self.mpd = mpd
                self.navigator = navigator
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
                        right: contentMargin.trailing
                    )
                }
                
                collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
                collectionView.backgroundColor = .clear
                
                super.init()
                
                collectionView.register(HostingCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
                collectionView.dataSource = self
                collectionView.delegate = self
            }

            func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
                data.count
            }

            func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! HostingCollectionViewCell
                let element = elementAt(indexPath)
                
                cell.updateContent(AnyView(
                    content(element)
                        .environment(mpd)
                        .environment(navigator)
                ))
                return cell
            }

            func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
                let width = calculateItemWidth(for: collectionView)
                
                if let fixedHeight = rowHeight {
                    return CGSize(width: width, height: fixedHeight)
                }
                
                return calculateDynamicSize(for: elementAt(indexPath), width: width)
            }
            
            private func elementAt(_ indexPath: IndexPath) -> Data.Element {
                data[data.index(data.startIndex, offsetBy: indexPath.item)]
            }
            
            private func calculateItemWidth(for collectionView: UICollectionView) -> CGFloat {
                let horizontalMargins = (contentMargin?.leading ?? 0) + (contentMargin?.trailing ?? 0)
                return collectionView.bounds.width - horizontalMargins
            }
            
            private func calculateDynamicSize(for element: Data.Element, width: CGFloat) -> CGSize {
                let elementID = element.id
                
                if let cachedSize = sizeCache[elementID], cachedSize.width == width {
                    return cachedSize
                }
                
                let contentView = content(element)
                    .environment(mpd)
                    .environment(navigator)
                    .frame(width: width)
                
                let hostingController = UIHostingController(rootView: contentView)
                let size = hostingController.view.systemLayoutSizeFitting(
                    CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                sizeCache[elementID] = size
                
                return size
            }
        }
    #endif
}
