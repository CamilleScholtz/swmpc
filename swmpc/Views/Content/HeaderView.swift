//
//  HeaderView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct HeaderView: View {
    @Environment(MPD.self) private var mpd

    let destination: CategoryDestination
    @Binding var isSearching: Bool

    @State private var query = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            if !isSearching {
                Text(destination.label)
                    .font(.headline)

                Spacer()
            } else {
                TextField("Search", text: $query)

                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(.secondarySystemFill))
                    .cornerRadius(4)
                    .disableAutocorrection(true)
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
            .styledButton()
        }
        .frame(height: 50 - 7.5)
        .padding(.horizontal, 15)
        .padding(.top, 7.5)
        .onChange(of: destination) {
            isSearching = false
        }
        .task(id: isSearching) {
            guard !isSearching else {
                return
            }

            query = ""
            mpd.queue.results = nil
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
