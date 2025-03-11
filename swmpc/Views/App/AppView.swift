//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct AppView: View {
    @Environment(MPD.self) private var mpd

    @State private var showError = false

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
                NavigationSplitView {
                    SidebarView()
                        .navigationSplitViewColumnWidth(180)
                } content: {
                    ContentView()
                        .navigationBarBackButtonHidden()
                        .navigationSplitViewColumnWidth(310)
                } detail: {
                    ViewThatFits {
                        DetailView()
                    }
                    .padding(60)
                }
                .background(.background)
            }
        }
        .toolbar {
            Color.clear
        }
    }
}
