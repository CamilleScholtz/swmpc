//
//  ServerPickerView.swift
//  swmpc
//
//  Created by Camille Scholtz on 30/11/2025.
//

import SFSafeSymbols
import SwiftUI

/// A view that displays discovered MPD servers and allows the user to select one.
struct ServerPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var discovery = ServerDiscovery()

    let onSelect: (ServerDiscovery.Server) -> Void

    var body: some View {
        List {
            if discovery.servers.isEmpty {
                ContentUnavailableView {
                    Label(
                        discovery.isSearching ? "Searching..." : "No Servers Found",
                        systemSymbol: discovery.isSearching ? .magnifyingglass : .serverRack
                    )
                } description: {
                    Text(discovery.isSearching
                        ? "Looking for MPD servers on your network."
                        : "Make sure your MPD server has Zeroconf enabled.")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(discovery.servers) { server in
                        Button {
                            onSelect(server)
                            dismiss()
                        } label: {
                            Label(server.name, systemSymbol: .serverRack)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Available Servers")
                        Spacer()
                        if discovery.isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
            }
        }
        .animation(.default, value: discovery.servers)
        #if os(iOS)
        .navigationTitle("Discover Servers")
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            discovery.startBrowsing()
        }
        .onDisappear {
            discovery.stopBrowsing()
        }
    }
}
