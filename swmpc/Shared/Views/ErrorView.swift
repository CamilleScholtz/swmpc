//
//  ErrorView.swift
//  swmpc
//
//  Created by Camille Scholtz on 27/03/2025.
//

import NavigatorUI
import SwiftUI

struct ErrorView: View {
    @Environment(MPD.self) private var mpd
    #if os(iOS)
        @Environment(\.navigator) private var navigator
    #elseif os(macOS)
        @Environment(\.openSettings) private var openSettings
    #endif

    @State private var showError = false

    var body: some View {
        VStack(alignment: .center) {
            ProgressView()
                .offset(y: -20)

            Group {
                Text("Could not establish connection to MPD.")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack(spacing: 0) {
                    Text("Please check your ")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button {
                        #if os(iOS)
                            navigator.navigate(to: SidebarDestination.settings, method: .sheet)
                        #elseif os(macOS)
                            openSettings()
                        #endif
                    } label: {
                        Text("swmpc settings")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    Text(" and server.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

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
    }
}
