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
                #if os(iOS)
                    .padding(.leading, 4)
                #endif

                Spacer()
            } else {
                TextField("Search", text: $query)
                #if os(iOS)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
                #elseif os(macOS)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(.secondarySystemFill))
                    .cornerRadius(4)
                #endif
                    .disableAutocorrection(true)
                #if os(iOS)
                    .autocapitalization(.none)
                #endif
                    .focused($isFocused)
                    .onAppear {
                        query = ""
                        isFocused = true
                    }
                    .onDisappear {
                        query = ""
                        isFocused = false
                    }
            }

            Button(action: {
                isSearching.toggle()
            }) {
                Image(systemSymbol: isSearching ? .xmarkCircleFill : .magnifyingglass)
                    .frame(width: 22, height: 22)
                    .foregroundColor(.primary)
                    .padding(4)
                    .contentShape(Circle())
            }
            .button()
        }
        #if os(iOS)
        .frame(height: 44)
        #elseif os(macOS)
        .frame(height: 50 - 7.5)
        #endif
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
