//
//  ContentDestinationViews.swift
//  swmpc
//
//  Created by Camille Scholtz on 15/03/2025.
//

import Navigator
import SwiftUI

extension ContentDestination: NavigationDestination {
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            switch self {
            case let .album(album):
                AlbumSongsView(for: album)
                    .padding(.top, 25)
            case let .artist(artist):
                ArtistAlbumsView(for: artist)
                    .padding(.top, 25)
            }

            BackButtonView()
                .offset(x: -15, y: 5)
        }
        .ignoresSafeArea()
    }
}

struct BackButtonView: View {
    @Environment(\.navigator) private var navigator

    @State private var isHovering = false

    var body: some View {
        Image(systemSymbol: .chevronBackward)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color(.secondarySystemFill) : .clear)
            )
            .padding(.top, 12)
            .animation(.interactiveSpring, value: isHovering)
            .onHover { value in
                isHovering = value
            }
            .onTapGesture {
                navigator.back()
            }
    }
}
