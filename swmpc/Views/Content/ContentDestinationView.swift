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
            #if os(iOS)
                let spacing: CGFloat = 10
            #elseif os(macOS)
                let spacing: CGFloat = 15
            #endif

            VStack(alignment: .leading, spacing: spacing) {
                #if os(macOS)
                    BackButtonView()
                        .padding(.top, 12)
                        .offset(y: 5)
                #endif

                switch destination {
                case let .album(album):
                    AlbumSongsView(for: album)
                    #if os(macOS)
                        .padding(.top, 5)
                    #endif
                case let .artist(artist):
                    ArtistAlbumsView(for: artist)
                    #if os(macOS)
                        .padding(.top, 5)
                    #endif
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
        }
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
            .button()
        }
    }
#endif
