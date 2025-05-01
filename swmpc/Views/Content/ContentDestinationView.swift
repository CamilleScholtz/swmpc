//
//  ContentDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import SwiftUI
import SwiftUIIntrospect

struct ContentDestinationView: View {
    @Environment(\.dismiss) private var dismiss

    let destination: ContentDestination

    var body: some View {
        List {
            #if os(macOS)
                BackButtonView()
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 15, leading: 7.5, bottom: 0, trailing: 7.5))
            #endif

            Section {
                switch destination {
                case let .album(album):
                    AlbumSongsView(for: album)
                case let .artist(artist):
                    ArtistAlbumsView(for: artist)
                }
            }
            .listRowSeparator(.hidden)
            #if os(iOS)
                .listRowInsets(.init(top: 7.5, leading: 15, bottom: 7.5, trailing: 15))
            #elseif os(macOS)
                .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
            #endif
        }
        .listStyle(.plain)
        .safeAreaPadding(.bottom, 7.5)
        .contentMargins(.bottom, -7.5, for: .scrollIndicators)
        #if os(macOS)
            .ignoresSafeArea()
        #endif
    }
}

#if os(macOS)
    struct BackButtonView: View {
        @Environment(NavigationManager.self) private var navigator

        var body: some View {
            Button(action: {
                navigator.goBack()
            }) {
                Image(systemSymbol: .chevronBackward)
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .styledButton()
        }
    }
#endif
