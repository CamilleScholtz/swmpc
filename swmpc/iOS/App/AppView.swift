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
    @Environment(\.navigator) private var navigator
    @Environment(MPD.self) private var mpd

    @State private var destination: SidebarDestination = .albums

    @State private var showError = false

    @State private var showQueueAlert = false
    @State private var playlistToQueue: Playlist?

    @State private var isPopupBarPresented = true
    @State private var isPopupOpen = false

    var body: some View {
        Group {
            if mpd.status.state == nil {
                VStack(alignment: .center) {
                    ProgressView()
                        .offset(y: -20)

                    VStack {
                        Text("Could not establish connection to MPD.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Please check your configuration and server.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let error = mpd.error {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .monospaced()
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                        }
                    }
                    .opacity(showError ? 1 : 0)
                    .animation(.spring, value: showError)
                }
                .task(priority: .medium) {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else {
                        return
                    }

                    showError = true
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
                }
                .overlay(
                    LoadingView(destination: $destination)
                )
                .handleQueueChange(destination: $destination)
                .popup(isBarPresented: $isPopupBarPresented, isPopupOpen: $isPopupOpen) {
                    DetailView()
                }
                .popupBarProgressViewStyle(.top)
            }
        }
    }
}
