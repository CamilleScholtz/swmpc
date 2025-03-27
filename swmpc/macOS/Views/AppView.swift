//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import NavigatorUI
import SwiftUI

struct AppView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    @State private var destination: SidebarDestination = .albums

    @State private var showQueueAlert = false
    @State private var playlistToQueue: Playlist?

    var body: some View {
        Group {
            if mpd.status.state == nil {
                ErrorView()
            } else {
                NavigationSplitView {
                    SidebarView(destination: $destination)
                        .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: .infinity)
                } content: {
                    ManagedNavigationStack(name: "content") {
                        destination
                            .navigationDestination(ContentDestination.self)
                    }
                    .navigationSplitViewColumnWidth(310)
                    .navigationBarBackButtonHidden(true)
                    .ignoresSafeArea()
                    .overlay(
                        LoadingView(destination: $destination)
                    )
                } detail: {
                    ViewThatFits {
                        DetailView()
                    }
                    .padding(60)
                }
                .background(.background)
            }
        }
        .frame(minWidth: 180 + 310 + 650, minHeight: 650)
        .toolbar {
            Color.clear
        }
    }
}
