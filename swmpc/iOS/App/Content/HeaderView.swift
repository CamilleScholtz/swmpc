//
//  HeaderView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct HeaderView: View {
    @Environment(MPD.self) private var mpd

    @Binding var destination: SidebarDestination
    @Binding var isSearching: Bool

    @State private var query = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            if !isSearching {
                Text(destination.label)
                    .font(.headline)
                    .padding(.leading, 4)

                Spacer()

                Button(action: {
                    isSearching = true
                }) {
                    Image(systemSymbol: .magnifyingglass)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.primary)
                        .padding(4)
                }
            } else {
                TextField("Search", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .focused($isFocused)
                    .onAppear {
                        query = ""
                        isFocused = true
                    }
                    .onDisappear {
                        query = ""
                        isFocused = false
                    }

                Button(action: {
                    isSearching = false
                }) {
                    Image(systemSymbol: .xmarkCircleFill)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 15)
        .padding(.top, 7.5)
        .onChange(of: destination) {
            isSearching = false
        }
        .task(id: isSearching) {
            if !isSearching {
                query = ""
                mpd.queue.results = nil
            }
        }
        .task(id: query) {
            guard isSearching else {
                return
            }

            if query.isEmpty {
                mpd.queue.results = nil
                return
            }

            try? await mpd.queue.search(for: query)
        }
    }
}
