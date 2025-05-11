//
//  HeaderView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI
import SwiftUIIntrospect

struct HeaderView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

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
        .padding(.leading, 15)
        .padding(.trailing, 7.5)
        .frame(height: 50 + 7.5)
        .background(.background)
        .shadow(color: colorScheme == .dark ? .black : Color(.secondarySystemFill), radius: 0, y: 1)
        .onChange(of: destination) {
            isSearching = false
        }
        .onChange(of: isSearching) { _, value in
            guard !value else {
                return
            }

            mpd.queue.results = nil
        }
        .task(id: query) {
            guard isSearching else {
                return
            }

            if query.isEmpty {
                mpd.queue.results = nil
            } else {
                try? await mpd.queue.search(for: query)
            }
        }
    }
}
