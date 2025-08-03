//
//  RecyclingScrollView.swift
//  swmpc
//
//  Created by Camille Scholtz on 03/08/2025.
//

import SwiftUI

struct RecyclingScrollView<ID: Hashable, Content: View>: View {
    let rowIDs: [ID]
    let rowHeight: CGFloat
    
    @ViewBuilder var content: (ID) -> Content

    @State private var visibleRange: Range<Int> = 0..<1

    var numberOfRows: Int { rowIDs.count }

    struct RowData: Identifiable {
        let fragmentID: Int
        let index: Int
        let value: ID

        var id: Int { fragmentID }
    }

    var visibleRows: [RowData] {
        if rowIDs.isEmpty {
            return []
        }

        let lowerBound = min(
            max(0, visibleRange.lowerBound),
            rowIDs.count - 1
        )
        let upperBound = max(
            min(rowIDs.count, visibleRange.upperBound),
            lowerBound + 1
        )

        let range = lowerBound..<upperBound
        let rowSlice = rowIDs[lowerBound..<upperBound]

        let rowData = zip(rowSlice, range).map { row in
            RowData(
                fragmentID: row.1 % range.count,
                index: row.1,
                value: row.0
            )
        }
        
        return rowData
    }

    var body: some View {
        ScrollView(.vertical) {
            OffsetLayout(
                totalRowCount: rowIDs.count,
                rowHeight: rowHeight
            ) {
                ForEach(visibleRows) { row in
                    content(row.value)
                        .layoutValue(key: LayoutIndex.self, value: row.index)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaPadding(.bottom, 7.5)
        .contentMargins(.bottom, -7.5, for: .scrollIndicators)
        .contentMargins(.horizontal, 15, for: .scrollContent)
        .onScrollGeometryChange(
            for: Range<Int>.self,
            of: { geo in
                self.computeVisibleRange(in: geo.visibleRect)
            },
            action: { _, newValue in
                self.visibleRange = newValue
            }
        )
    }

    nonisolated func computeVisibleRange(in rect: CGRect) -> Range<Int> {
        let lowerBound = Int(
            max(0, floor(rect.minY / rowHeight))
        )
        let rowsThatFitInRange = Int(
            ceil(rect.height / rowHeight) + 3
        )

        let upperBound = max(
            lowerBound + rowsThatFitInRange,
            lowerBound + 1
        )

        return lowerBound..<upperBound
    }
}

nonisolated struct OffsetLayout: Layout {
    let totalRowCount: Int
    let rowHeight: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        CGSize(
            width: proposal.width ?? 0,
            height: rowHeight * CGFloat(totalRowCount)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for subview in subviews {
            let index = subview[LayoutIndex.self]
            subview.place(
                at: CGPoint(
                    x: bounds.midX,
                    y: bounds.minY + rowHeight * CGFloat(index)
                ),
                anchor: .top,
                proposal: .init(
                    width: proposal.width,
                    height: rowHeight
                )
            )
        }
    }
}

nonisolated struct LayoutIndex: LayoutValueKey {
    static let defaultValue: Int = 0
    typealias Value = Int
}
