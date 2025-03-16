//
//  HeaderView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct HeaderView: View {
    @Environment(MPD.self) private var mpd

    @Binding var selectedDestination: SidebarDestination?

    @State private var isSearching = false
    @State private var isHovering = false
    @State private var query = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            if !isSearching {
                Text(selectedDestination?.label ?? "")
                    .font(.headline)

                Spacer()

                Image(systemSymbol: .magnifyingglass)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHovering ? Color(.secondarySystemFill) : .clear)
                    )
                    .animation(.interactiveSpring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                    .onTapGesture(perform: {
                        isSearching = true
                    })
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

                Image(systemSymbol: .xmarkCircle)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHovering ? Color(.secondarySystemFill) : .clear)
                    )
                    .animation(.interactiveSpring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                    .onTapGesture(perform: {
                        isSearching = false
                    })
            }
        }
        .frame(height: 50 - 7.5)
        .padding(.horizontal, 15)
        .padding(.top, 7.5)
        .onChange(of: selectedDestination) {
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
