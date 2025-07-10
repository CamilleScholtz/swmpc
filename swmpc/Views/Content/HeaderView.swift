//
//  HeaderView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import ButtonKit
import SwiftUI
import SwiftUIIntrospect

struct HeaderView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    let destination: CategoryDestination
    @Binding var isSearching: Bool
    @Binding var searchQuery: String

    @State private var query = ""

    @State private var showAlert = false
    @State private var playlistToQueue: Playlist?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            if !isSearching {
                Text(destination.label)
                    .font(.headline)

                Spacer()

                if case let .playlist(playlist) = destination {
                    Button(action: {
                        showAlert = true
                    }) {
                        Image(systemSymbol: .squareAndArrowDownOnSquare)
                            .frame(width: 22, height: 22)
                            .foregroundColor(.primary)
                            .padding(4)
                            .contentShape(Circle())
                            .offset(y: -1)
                    }
                    .styledButton()
                    .alert("Queue Playlist", isPresented: $showAlert) {
                        Button("Cancel", role: .cancel) {}

                        AsyncButton("Queue") {
                            try await ConnectionManager.command().loadPlaylist(playlist)
                        }
                    } message: {
                        Text("This will overwrite the current queue.")
                    }
                }
            } else {
                TextField("Search", text: $searchQuery)
                    .introspect(.textField, on: .macOS(.v15)) {
                        $0.drawsBackground = true
                        $0.backgroundColor = .clear
                    }
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(.secondarySystemFill))
                    .cornerRadius(4)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .onAppear {
                        isFocused = true
                    }
                    .onDisappear {
                        isFocused = false
                    }
            }

            if destination.type != .playlist {
                Button(role: .cancel, action: {
                    isSearching.toggle()
                }) {
                    Image(systemSymbol: isSearching ? .xmarkCircleFill : .magnifyingglass)
                        .frame(width: 22, height: 22)
                        .foregroundColor(.primary)
                        .padding(4)
                        .contentShape(Circle())
                }
                .styledButton()
                .keyboardShortcut(isSearching ? .cancelAction : .none)
            }
        }
        .padding(.leading, 15)
        .padding(.trailing, 7.5)
        .frame(height: 50 + 7.5)
        .background(.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(colorScheme == .dark ? .black : Color(.secondarySystemFill)),
            alignment: .bottom
        )
        .onChange(of: destination) {
            isSearching = false
            searchQuery = ""
        }
    }
}
