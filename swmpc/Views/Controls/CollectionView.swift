import SwiftUI
#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

#if os(macOS)
    final class HostingCollectionViewItem: NSCollectionViewItem {
        private(set) var hostingView: NSHostingView<AnyView>?

        override func loadView() {
            view = NSView()
        }

        func updateContent(_ content: AnyView) {
            if let hostingView {
                hostingView.rootView = content
            } else {
                let hostingView = NSHostingView(rootView: content)
                hostingView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(hostingView)

                NSLayoutConstraint.activate([
                    hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    hostingView.topAnchor.constraint(equalTo: view.topAnchor),
                    hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])

                self.hostingView = hostingView
            }
        }
    }

    typealias PlatformViewRepresentable = NSViewRepresentable

#elseif os(iOS)
    final class HostingCollectionViewCell: UICollectionViewCell {
        private(set) var hostingController: UIHostingController<AnyView>?

        func updateContent(_ content: AnyView) {
            if let hostingController {
                hostingController.rootView = content
            } else {
                let hostingController = UIHostingController(rootView: content)
                hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                hostingController.view.backgroundColor = .clear
                contentView.addSubview(hostingController.view)

                NSLayoutConstraint.activate([
                    hostingController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                    hostingController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                    hostingController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                    hostingController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                ])

                self.hostingController = hostingController
            }
        }
    }

    typealias PlatformViewRepresentable = UIViewRepresentable
#endif

struct CollectionView<Data: RandomAccessCollection, Content: View>: PlatformViewRepresentable
    where Data.Element: Identifiable & Hashable
{
    let data: Data
    let rowHeight: CGFloat?
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
            let coordinator = context.coordinator
            let hasDataChanged = !coordinator.data.elementsEqual(data) { $0.id == $1.id }

            coordinator.data = data
            coordinator.content = content
            coordinator.mpd = mpd
            coordinator.navigator = navigator
            coordinator.rowHeight = rowHeight

            if hasDataChanged {
                coordinator.collectionView.reloadData()
            }

            handleScrollToItem(coordinator: coordinator)
        }

    #elseif os(iOS)
        func makeUIView(context: Context) -> UICollectionView {
            context.coordinator.collectionView
        }

        func updateUIView(_: UICollectionView, context: Context) {
            let coordinator = context.coordinator
            let hasDataChanged = !coordinator.data.elementsEqual(data) { $0.id == $1.id }

            coordinator.data = data
            coordinator.content = content
            coordinator.mpd = mpd
            coordinator.navigator = navigator
            coordinator.rowHeight = rowHeight

            if hasDataChanged {
                coordinator.collectionView.reloadData()
            }

            handleScrollToItem(coordinator: coordinator)
        }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(data: data, content: content, mpd: mpd, navigator: navigator, rowHeight: rowHeight)
    }

    private func handleScrollToItem(coordinator: Coordinator) {
        guard let id = scrollTo,
              let index = data.firstIndex(where: { $0.id == id }) else { return }

        let itemIndex = data.distance(from: data.startIndex, to: index)
        let indexPath = IndexPath(item: itemIndex, section: 0)

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
            private var sizeCache: [Data.Element.ID: NSSize] = [:]
            private let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")
            var rowHeight: CGFloat?

            init(data: Data, content: @escaping (Data.Element) -> Content, mpd: MPD, navigator: NavigationManager, rowHeight: CGFloat?) {
                self.data = data
                self.content = content
                self.mpd = mpd
                self.navigator = navigator
                self.rowHeight = rowHeight
                collectionView = NSCollectionView()

                super.init()

                setupCollectionView()
            }

            private func setupCollectionView() {
                let layout = NSCollectionViewFlowLayout()
                layout.minimumLineSpacing = 0
                layout.minimumInteritemSpacing = 0
                collectionView.collectionViewLayout = layout

                collectionView.register(HostingCollectionViewItem.self, forItemWithIdentifier: cellIdentifier)
                collectionView.dataSource = self
                collectionView.delegate = self
            }

            func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
                data.count
            }

            func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
                let item = collectionView.makeItem(withIdentifier: cellIdentifier, for: indexPath) as! HostingCollectionViewItem
                let element = data[data.index(data.startIndex, offsetBy: indexPath.item)]

                let contentView = AnyView(
                    content(element)
                        .environment(mpd)
                        .environment(navigator),
                )

                item.updateContent(contentView)
                return item
            }

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
                let width = collectionView.bounds.width

                if let fixedHeight = rowHeight {
                    return NSSize(width: width, height: fixedHeight)
                }

                let element = data[data.index(data.startIndex, offsetBy: indexPath.item)]
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

            func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, shouldInvalidateLayoutForBoundsChange newBounds: NSRect) -> Bool {
                if collectionView.bounds.width != newBounds.width {
                    sizeCache.removeAll()
                    return true
                }
                return false
            }
        }

    #elseif os(iOS)
        final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
            var data: Data
            var content: (Data.Element) -> Content
            var mpd: MPD
            var navigator: NavigationManager
            let collectionView: UICollectionView
            private var sizeCache: [Data.Element.ID: CGSize] = [:]
            private let cellIdentifier = String(describing: HostingCollectionViewCell.self)
            var rowHeight: CGFloat?

            init(data: Data, content: @escaping (Data.Element) -> Content, mpd: MPD, navigator: NavigationManager, rowHeight: CGFloat?) {
                self.data = data
                self.content = content
                self.mpd = mpd
                self.navigator = navigator
                self.rowHeight = rowHeight

                let layout = UICollectionViewFlowLayout()
                layout.minimumLineSpacing = 0
                layout.minimumInteritemSpacing = 0
                collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

                super.init()

                setupCollectionView()
            }

            private func setupCollectionView() {
                collectionView.register(HostingCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
                collectionView.dataSource = self
                collectionView.delegate = self
                collectionView.backgroundColor = .clear
            }

            func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
                data.count
            }

            func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! HostingCollectionViewCell
                let element = data[data.index(data.startIndex, offsetBy: indexPath.item)]

                let contentView = AnyView(
                    content(element)
                        .environment(mpd)
                        .environment(navigator),
                )

                cell.updateContent(contentView)
                return cell
            }

            func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
                let width = collectionView.bounds.width

                if let fixedHeight = rowHeight {
                    return CGSize(width: width, height: fixedHeight)
                }

                let element = data[data.index(data.startIndex, offsetBy: indexPath.item)]
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
                    verticalFittingPriority: .fittingSizeLevel,
                )
                sizeCache[elementID] = size

                return size
            }
        }
    #endif
}
