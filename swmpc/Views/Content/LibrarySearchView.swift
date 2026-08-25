//
//  LibrarySearchView.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/08/2026.
//

import MPDKit
import SFSafeSymbols
import SwiftUI

/// The search fields each media type is matched against.
struct SearchFieldSelection: Equatable {
    let artists: SearchFields
    let albums: SearchFields
    let songs: SearchFields
}

/// Sizes governing how search results are presented.
private enum SearchLayout {
    /// The number of matches a section shows before it has to be expanded.
    static let collapsedLimit = 5

    /// The shortest query that is searched for.
    static let minimumQueryLength = 2
}

/// The result of searching the whole library for a query.
///
/// Artists, albums, and songs are matched at once and grouped per type, so a
/// song can be found without first knowing which category it lives in.
///
/// Only the query itself comes from outside, which is what lets both
/// platforms share this view while keeping the search field they each want:
/// iOS types into the search tab's `searchable` field, macOS into
/// `SearchFieldView`.
struct LibrarySearchView<Placeholder: View>: View {
    @Environment(MPD.self) private var mpd

    @AppStorage(Setting.albumSearchFields) private var albumSearchFields = SearchFields.default
    @AppStorage(Setting.artistSearchFields) private var artistSearchFields = SearchFields.default
    @AppStorage(Setting.songSearchFields) private var songSearchFields = SearchFields.default

    /// The query to match the library against.
    let query: String

    /// Whether the collections that are searched are loaded as soon as this
    /// view appears.
    ///
    /// A destination that exists only to be searched can pay for that load up
    /// front; a category list that merely offers a search field should not,
    /// and loads on the first real query instead.
    var preloadsLibrary = false

    /// The media type whose matches are shown first, when it has any.
    ///
    /// A search started from a category leads with that category, so
    /// searching from Albums answers with albums before artists and songs.
    var preferredType: MediaType?

    /// Shown until the query matches something, which keeps the browsing
    /// list mounted while a search runs rather than tearing it down and
    /// putting it back on every query.
    @ViewBuilder let placeholder: Placeholder

    @State private var results = SearchResults.empty
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var expandedTypes: Set<MediaType> = []

    /// The media types in the order their sections are shown, leading with
    /// the preferred one.
    private var orderedTypes: [MediaType] {
        let types: [MediaType] = [.artist, .album, .song]

        guard let preferredType, types.contains(preferredType) else {
            return types
        }

        return [preferredType] + types.filter { $0 != preferredType }
    }

    /// Whether the query is long enough to be searched for.
    private var hasQuery: Bool {
        Self.isSearchable(query)
    }

    /// Whether a query is worth searching for, which a single character is
    /// not since it matches most of the library.
    ///
    /// - Parameter query: The query to weigh.
    /// - Returns: `true` when the query should be searched for.
    private static func isSearchable(_ query: String) -> Bool {
        query.count >= SearchLayout.minimumQueryLength
    }

    private var fields: SearchFieldSelection {
        SearchFieldSelection(artists: artistSearchFields.resolved(for: .artist, on: mpd.state),
                             albums: albumSearchFields.resolved(for: .album, on: mpd.state),
                             songs: songSearchFields.resolved(for: .song, on: mpd.state))
    }

    var body: some View {
        Group {
            if !results.isEmpty {
                resultsList
            } else if hasQuery, !isSearching {
                EmptyStateView(symbol: .magnifyingglass,
                               title: "No results for ‘\(query)’",
                               description: "Check the spelling or try a new search.")
            } else {
                placeholder
                    .overlay {
                        if isSearching {
                            ProgressView()
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard preloadsLibrary else {
                return
            }

            try? await mpd.database.prepareSearch()
        }
        .onChange(of: query) { _, value in
            performSearch(query: value, fields: fields)
        }
        .onChange(of: fields) { _, value in
            performSearch(query: query, fields: value)
        }
    }

    private var resultsList: some View {
        List {
            ForEach(orderedTypes, id: \.self) { type in
                section(for: type)
            }
        }
        .mediaListStyle()
    }

    /// The section of matches of one media type.
    ///
    /// - Parameter type: The media type to build the section for.
    /// - Returns: The section, or nothing when this type had no matches.
    @ViewBuilder
    private func section(for type: MediaType) -> some View {
        switch type {
        case .artist:
            section("Artists", count: results.artists.count, type: .artist) {
                ForEach(visible(results.artists, for: .artist), id: \.id) { artist in
                    ArtistView(for: artist, albumCount: results.artistAlbumCounts[artist.id] ?? 0)
                        .equatable()
                        .mediaRowStyle()
                }
            }
        case .album:
            section("Albums", count: results.albums.count, type: .album) {
                ForEach(visible(results.albums, for: .album), id: \.id) { album in
                    AlbumView(for: album)
                        .equatable()
                        .mediaRowStyle()
                }
            }
        case .song:
            section("Songs", count: results.songs.count, type: .song) {
                ForEach(visible(results.songs, for: .song), id: \.id) { song in
                    SongView(for: song, source: .database)
                        .equatable()
                        .mediaRowStyle()
                }
            }
        case .playlist:
            EmptyView()
        }
    }

    /// A group of matches of one media type, collapsed to the first few
    /// results until the user asks for all of them.
    ///
    /// - Parameters:
    ///   - title: The section header.
    ///   - count: The total number of matches of this type.
    ///   - type: The media type the section shows.
    ///   - rows: The rows for the currently visible matches.
    /// - Returns: The section, or nothing when this type had no matches.
    @ViewBuilder
    private func section(_ title: LocalizedStringKey, count: Int, type: MediaType,
                         @ViewBuilder rows: () -> some View) -> some View
    {
        if count > 0 {
            Section {
                rows()

                if count > SearchLayout.collapsedLimit, !expandedTypes.contains(type) {
                    Button {
                        expandedTypes.insert(type)
                    } label: {
                        HStack {
                            Text("Show All")
                                .font(.headline)

                            Spacer()

                            Text(count.formatted())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .mediaRowStyle()
                }
            } header: {
                Text(title)
            }
        }
    }

    /// The matches of a type that are currently shown, which is all of them
    /// once the user expanded the section.
    ///
    /// - Parameters:
    ///   - items: All matches of the type.
    ///   - type: The media type the matches belong to.
    /// - Returns: The matches to build rows for.
    private func visible<T>(_ items: [T], for type: MediaType) -> [T] {
        guard !expandedTypes.contains(type) else {
            return items
        }

        return Array(items.prefix(SearchLayout.collapsedLimit))
    }

    private func performSearch(query: String, fields: SearchFieldSelection) {
        searchTask?.cancel()

        guard Self.isSearchable(query) else {
            results = .empty
            expandedTypes = []
            isSearching = false

            return
        }

        isSearching = true

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else {
                return
            }

            try? await mpd.database.prepareSearch()
            guard !Task.isCancelled else {
                return
            }

            let results = await mpd.database.searchLibrary(query,
                                                           artistFields: fields.artists,
                                                           albumFields: fields.albums,
                                                           songFields: fields.songs)
            guard !Task.isCancelled else {
                return
            }

            self.results = results
            expandedTypes = []
            isSearching = false
        }
    }
}

/// The menu picking which fields a search matches each media type against.
///
/// Artists are left out: they can only be matched on their name, so there is
/// nothing to choose.
struct SearchFieldsMenu: View {
    @Environment(MPD.self) private var mpd

    @AppStorage(Setting.albumSearchFields) private var albumSearchFields = SearchFields.default
    @AppStorage(Setting.songSearchFields) private var songSearchFields = SearchFields.default

    var body: some View {
        Menu {
            Section {
                toggles(for: .song, fields: $songSearchFields)
            } header: {
                Text("Songs")
            }

            Section {
                toggles(for: .album, fields: $albumSearchFields)
            } header: {
                Text("Albums")
            }
        } label: {
            Image(systemSymbol: .sliderHorizontal3)
            #if os(macOS)
                .foregroundStyle(.secondary)
            #endif
        }
        .menuIndicator(.hidden)
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .fixedSize()
        #endif
        .accessibilityLabel(Text("Search Fields"))
    }

    /// Toggles for the fields a media type can be matched against.
    ///
    /// - Parameters:
    ///   - type: The media type whose fields are toggled.
    ///   - fields: The stored selection for that type.
    /// - Returns: One toggle per available field, omitting fields whose tag
    ///             the server is too old to send.
    private func toggles(for type: MediaType, fields: Binding<SearchFields>) -> some View {
        let available = Source.database.availableSearchFields(for: type)
            .filter { mpd.state.supports(minimumVersion: $0.minimumVersion) }

        return ForEach(available, id: \.self) { field in
            Toggle(isOn: Binding(
                get: { fields.wrappedValue.resolved(for: type, on: mpd.state).contains(field) },
                set: { _ in
                    var updated = fields.wrappedValue.resolved(for: type, on: mpd.state)
                    updated.toggle(field)

                    fields.wrappedValue = updated
                },
            )) {
                Label {
                    Text(field.label)
                } icon: {
                    Image(systemSymbol: field.symbol)
                }
            }
        }
    }
}
