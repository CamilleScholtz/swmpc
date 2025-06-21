//
//  ContentDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import SwiftUI

struct ContentDestinationView: View {
    @Environment(\.dismiss) private var dismiss

    let destination: ContentDestination

    var body: some View {
        ScrollView {
//            #if os(macOS)
//                BackButtonView()
//                    .listRowSeparator(.hidden)
//                    .listRowInsets(.init(top: 15, leading: 7.5, bottom: 0, trailing: 7.5))
//            #endif

            LazyVStack {
                switch destination {
                case let .album(album):
                    AlbumSongsView(for: album)
                case let .artist(artist):
                    ArtistAlbumsView(for: artist)
                }
            }
        }
        .contentMargins(.all, 15, for: .scrollContent)
        .scrollEdgeEffectStyle(.soft, for: .top)
        #if os(iOS)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BackButtonView()
                }
            }
        #endif
    }
}

struct BackButtonView: View {
    @Environment(NavigationManager.self) private var navigator

    var body: some View {
        Button(action: {
            navigator.goBack()
        }) {
            #if os(iOS)
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                    Text(navigator.category.label)
                }
            #elseif os(macOS)
                Image(systemSymbol: .chevronBackward)
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            #endif
        }
        #if os(macOS)
        .styledButton()
        #endif
    }
}
