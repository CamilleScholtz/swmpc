//
//  SearchView.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/08/2026.
//

import MPDKit
import SFSafeSymbols
import SwiftUI

#if os(iOS)
    /// The library-wide search destination behind the tab bar's search button.
    ///
    /// The tab's `searchable` field supplies the query and `LibrarySearchView`
    /// does the rest, so this only owns the placement that is specific to iOS.
    struct SearchView: View {
        @State private var query = ""

        var body: some View {
            LibrarySearchView(query: query, preloadsLibrary: true) {
                EmptyStateView(symbol: .magnifyingglass, title: "Search Library",
                               description: "Find artists, albums, and songs across your library.")
            }
            .navigationTitle(Text("Search"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Artists, albums, and songs"))
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem {
                    SearchFieldsMenu()
                }
            }
        }
    }
#endif
