//
//  EmptyStateView.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/08/2026.
//

import MPDKit
import SFSafeSymbols
import SwiftUI

/// The placeholder shown where a list would be when there is nothing to put
/// in it.
///
/// Every empty state in the app goes through this, so an empty library, an
/// empty playlist and a search that matched nothing all read the same: a
/// muted symbol above a muted title and explanation.
///
/// The content sits in a scroll view even though it never scrolls, so that
/// the toolbar above it treats it the same as the lists it stands in for and
/// draws the same edge.
struct EmptyStateView: View {
    /// The symbol describing what is missing.
    let symbol: SFSymbol

    /// What is missing.
    let title: LocalizedStringResource

    /// What the user can do about it.
    let description: LocalizedStringResource

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.medium) {
                Image(systemSymbol: symbol)
                    .font(.largeTitle)
                    .accessibilityHidden(true)

                VStack(spacing: Layout.Spacing.small / 2) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.subheadline)
                }
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Layout.Padding.large)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
