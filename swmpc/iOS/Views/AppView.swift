//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import LNPopupUI
import NavigatorUI
import SwiftUI

struct AppView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    @State private var destination: SidebarDestination = .albums

    @State private var showQueueAlert = false
    @State private var playlistToQueue: Playlist?

    @State private var isPopupBarPresented = true
    @State private var isPopupOpen = false

    var body: some View {
        Group {
            if mpd.status.state == nil {
                ManagedNavigationStack {
                    ErrorView()
                }
            } else {
                TabView(selection: $destination) {
                    ForEach(SidebarDestination.categories) { category in
                        ManagedNavigationStack {
                            category
                                .navigationDestination(ContentDestination.self)
                        }
                        .tabItem {
                            Label(category.label, systemSymbol: category.symbol)
                        }
                        .tag(category)
                    }
                    .overlay(
                        LoadingView(destination: $destination)
                    )
                }
                .handleQueueChange(destination: $destination)
                .popup(isBarPresented: $isPopupBarPresented, isPopupOpen: $isPopupOpen) {
                    DetailView()
                }
                .popupBarProgressViewStyle(.top)
            }
        }
    }
}
