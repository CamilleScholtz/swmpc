import AppKit
import SwiftUI

class HostingCollectionViewItem: NSCollectionViewItem {
    var hostingView: NSHostingView<AnyView>?

    override func loadView() {
        view = NSView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingView?.rootView = AnyView(EmptyView())
    }
}

struct CollectionView<Content: View, Data: RandomAccessCollection>:
    NSViewRepresentable where Data.Element: Identifiable, Data.Element: Hashable
{
    var data: Data
    var content: (Data.Element) -> Content
    @Binding var scrollTo: Data.Element.ID?
    var rowHeight: CGFloat?

    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()

        scrollView.hasVerticalScroller = true
        scrollView.documentView = context.coordinator.collectionView

        return scrollView
    }

    func updateNSView(_: NSScrollView, context: Context) {
        let oldData = context.coordinator.data

        context.coordinator.data = data
        context.coordinator.content = content
        context.coordinator.mpd = mpd
        context.coordinator.navigator = navigator
        context.coordinator.rowHeight = rowHeight

        // Smart update: only reload if data actually changed
        if !oldData.elementsEqual(data, by: { $0.id == $1.id }) {
            context.coordinator.collectionView.reloadData()
        }

        if let id = scrollTo, let index = data.firstIndex(where: { $0.id == id }) {
            let indexPath = IndexPath(item: data.distance(from: data.startIndex, to: index), section: 0)
            context.coordinator.collectionView.scrollToItems(at: [indexPath], scrollPosition: .top)

            // Debounce scroll resets
            context.coordinator.scrollDebouncer?.cancel()
            context.coordinator.scrollDebouncer = DispatchWorkItem {
                scrollTo = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: context.coordinator.scrollDebouncer!)
        }
    }

    func makeCoordinator() -> Coordinator<Content, Data> {
        Coordinator(data: data, content: content, mpd: mpd, navigator: navigator, rowHeight: rowHeight)
    }

    class Coordinator<InnerContent: View, InnerData: RandomAccessCollection>: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout where InnerData.Element: Identifiable, InnerData.Element: Hashable {
        var data: InnerData
        var content: (InnerData.Element) -> InnerContent
        var mpd: MPD
        var navigator: NavigationManager
        let collectionView: NSCollectionView
        var scrollDebouncer: DispatchWorkItem?
        var rowHeight: CGFloat?

        // Cache for cell sizes
        private var sizeCache: [InnerData.Element.ID: NSSize] = [:]

        init(data: InnerData, content: @escaping (InnerData.Element) -> InnerContent, mpd: MPD, navigator: NavigationManager, rowHeight: CGFloat?) {
            self.data = data
            self.content = content
            self.mpd = mpd
            self.navigator = navigator
            self.rowHeight = rowHeight
            collectionView = NSCollectionView()
            super.init()

            let layout = NSCollectionViewFlowLayout()
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            collectionView.collectionViewLayout = layout

            collectionView.register(HostingCollectionViewItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("Cell"))
            collectionView.dataSource = self
            collectionView.delegate = self
        }

        func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
            data.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), for: indexPath) as! HostingCollectionViewItem
            let element = data[data.index(data.startIndex, offsetBy: indexPath.item)]

            let contentView = AnyView(
                content(element)
                    .environment(mpd)
                    .environment(navigator),
            )

            // Reuse existing hosting view if available
            if let hostingView = item.hostingView {
                hostingView.rootView = contentView
            } else {
                // Create new hosting view only if needed
                let hostingView = NSHostingView(rootView: contentView)
                hostingView.translatesAutoresizingMaskIntoConstraints = false
                item.view.addSubview(hostingView)

                NSLayoutConstraint.activate([
                    hostingView.leadingAnchor.constraint(equalTo: item.view.leadingAnchor),
                    hostingView.trailingAnchor.constraint(equalTo: item.view.trailingAnchor),
                    hostingView.topAnchor.constraint(equalTo: item.view.topAnchor),
                    hostingView.bottomAnchor.constraint(equalTo: item.view.bottomAnchor),
                ])

                item.hostingView = hostingView
            }

            return item
        }

        func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
            let width = collectionView.bounds.width

            // Use fixed height if provided for better performance
            if let fixedHeight = rowHeight {
                return NSSize(width: width, height: fixedHeight)
            }

            // Otherwise use dynamic height calculation
            let element = data[data.index(data.startIndex, offsetBy: indexPath.item)]

            // Check cache first
            let cacheKey = element.id
            if let cachedSize = sizeCache[cacheKey], cachedSize.width == width {
                return cachedSize
            }

            // Calculate size only if not cached
            let contentView = content(element)
                .environment(mpd)
                .environment(navigator)
                .frame(width: width)

            let hostingView = NSHostingView(rootView: contentView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            let fittingSize = hostingView.fittingSize

            let size = NSSize(width: width, height: fittingSize.height)
            sizeCache[cacheKey] = size

            return size
        }

        // Clear cache when bounds change
        func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, shouldInvalidateLayoutForBoundsChange newBounds: NSRect) -> Bool {
            if collectionView.bounds.width != newBounds.width {
                sizeCache.removeAll()
                return true
            }
            return false
        }
    }
}
