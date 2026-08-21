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
    /// Unlike the category lists, which only ever match the media they are
    /// showing, this searches artists, albums, and songs at once and groups the
    /// matches per type, so a song can be found without first knowing which
    /// category it lives in.
    ///
    /// Every search re-prepares the collections it matches against, which is
    /// free once they are cached but reloads them after the database changed
    /// underneath an open search.
    struct SearchView: View {
        @Environment(MPD.self) private var mpd

        @AppStorage(Setting.albumSearchFields) private var albumSearchFields = SearchFields.default
        @AppStorage(Setting.artistSearchFields) private var artistSearchFields = SearchFields.default
        @AppStorage(Setting.songSearchFields) private var songSearchFields = SearchFields.default

        @State private var query = ""
        @State private var results = SearchResults.empty
        @State private var searchTask: Task<Void, Never>?
        @State private var isPreparing = true
        @State private var expandedTypes: Set<MediaType> = []

        /// The number of matches a section shows before it has to be expanded.
        private static let collapsedLimit = 5

        /// The shortest query that is searched for, since a single character
        /// matches most of the library.
        private static let minimumQueryLength = 2

        /// The search fields for each media type, so that a change to any of them
        /// re-runs the search.
        private struct Fields: Equatable {
            let artists: SearchFields
            let albums: SearchFields
            let songs: SearchFields
        }

        private var fields: Fields {
            Fields(artists: resolved(artistSearchFields, for: .artist),
                   albums: resolved(albumSearchFields, for: .album),
                   songs: resolved(songSearchFields, for: .song))
        }

        var body: some View {
            Group {
                if isPreparing {
                    ProgressView()
                } else if query.count < Self.minimumQueryLength {
                    ContentUnavailableView {
                        Label("Search Library", systemSymbol: .magnifyingglass)
                    } description: {
                        Text("Find artists, albums, and songs across your library.")
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    resultsList
                }
            }
            .navigationTitle(Text("Search"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Artists, albums, and songs"))
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem {
                    searchFieldsMenu
                }
            }
            .task {
                try? await mpd.database.prepareSearch()
                isPreparing = false

                performSearch(query: query, fields: fields)
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
                section("Artists", count: results.artists.count, type: .artist) {
                    ForEach(visible(results.artists, for: .artist), id: \.id) { artist in
                        ArtistView(for: artist, albumCount: results.artistAlbumCounts[artist.id] ?? 0)
                            .equatable()
                            .mediaRowStyle()
                    }
                }

                section("Albums", count: results.albums.count, type: .album) {
                    ForEach(visible(results.albums, for: .album), id: \.id) { album in
                        AlbumView(for: album)
                            .equatable()
                            .mediaRowStyle()
                    }
                }

                section("Songs", count: results.songs.count, type: .song) {
                    ForEach(visible(results.songs, for: .song), id: \.id) { song in
                        SongView(for: song, source: .database)
                            .equatable()
                            .mediaRowStyle()
                    }
                }
            }
            .mediaListStyle()
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

                    if count > Self.collapsedLimit, !expandedTypes.contains(type) {
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

        private var searchFieldsMenu: some View {
            Menu {
                Section {
                    fieldToggles(for: .song, fields: $songSearchFields)
                } header: {
                    Text("Songs")
                }

                Section {
                    fieldToggles(for: .album, fields: $albumSearchFields)
                } header: {
                    Text("Albums")
                }
            } label: {
                Image(systemSymbol: .sliderHorizontal3)
            }
            .menuIndicator(.hidden)
            .accessibilityLabel(Text("Search Fields"))
        }

        /// Toggles for the fields a media type can be matched against.
        ///
        /// - Parameters:
        ///   - type: The media type whose fields are toggled.
        ///   - fields: The stored selection for that type.
        /// - Returns: One toggle per available field.
        private func fieldToggles(for type: MediaType, fields: Binding<SearchFields>) -> some View {
            ForEach(Source.database.availableSearchFields(for: type), id: \.self) { field in
                Toggle(isOn: Binding(
                    get: { resolved(fields.wrappedValue, for: type).contains(field) },
                    set: { _ in
                        var updated = resolved(fields.wrappedValue, for: type)
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

            return Array(items.prefix(Self.collapsedLimit))
        }

        /// Falls back to the default fields for a media type when the user turned
        /// all of its fields off, which would otherwise match nothing.
        ///
        /// - Parameters:
        ///   - fields: The stored selection.
        ///   - type: The media type the selection belongs to.
        /// - Returns: The fields to match against.
        private func resolved(_ fields: SearchFields, for type: MediaType) -> SearchFields {
            fields.isEmpty ? Source.database.defaultSearchFields(for: type) : fields
        }

        private func performSearch(query: String, fields: Fields) {
            searchTask?.cancel()

            guard query.count >= Self.minimumQueryLength, !isPreparing else {
                results = .empty
                expandedTypes = []

                return
            }

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
            }
        }
    }
#endif
