//
//  ServerEditView.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/12/2025.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI

struct ServerEditView: View {
    @Environment(MPD.self) private var mpd
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    let server: Server?

    @State private var name: String
    @State private var host: String
    @State private var port: Int
    @State private var password: String
    @State private var artworkGetter: ArtworkGetter

    private var isNew: Bool { server == nil }

    init(server: Server?) {
        self.server = server
        _name = State(initialValue: server?.name ?? "")
        _host = State(initialValue: server?.host ?? "localhost")
        _port = State(initialValue: server?.port ?? 6600)
        _password = State(initialValue: server?.password ?? "")
        _artworkGetter = State(initialValue: server?.artworkGetter ?? .library)
    }

    var body: some View {
        #if os(iOS)
            NavigationStack {
                formContent
                    .navigationTitle(isNew ? "Add Server" : "Edit Server")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            AsyncButton("Save") {
                                await saveServer()
                            }
                            .disabled(host.isEmpty)
                        }
                    }
            }
        #elseif os(macOS)
            VStack(spacing: 0) {
                formContent
                    .padding()

                Divider()

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    AsyncButton("Save") {
                        await saveServer()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(host.isEmpty)
                }
                .padding()
            }
            .frame(width: 400)
        #endif
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            #if os(iOS)
                Section {
                    TextField("Name", text: $name)
                        .autocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Optional display name for this server.")
                }

                Section {
                    TextField("Host", text: $host)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    TextField("Port", value: $port, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                } header: {
                    Text("Server")
                } footer: {
                    Text("The hostname and port of your MPD server.")
                }

                Section {
                    SecureField("Password", text: $password)
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Leave empty if your server doesn't require authentication.")
                }

                Section {
                    Picker("Retrieval Method", selection: $artworkGetter) {
                        Text("Library").tag(ArtworkGetter.library)
                        Text("Metadata").tag(ArtworkGetter.metadata)
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Artwork")
                } footer: {
                    Text("Library searches for cover files in the song's directory. Metadata extracts artwork from the song file, but is slower.")
                }
            #elseif os(macOS)
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Optional display name for this server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextField("Host", text: $host)
                        .textFieldStyle(.roundedBorder)
                    TextField("Port", value: $port, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Server")
                }

                Section {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Leave empty if your server doesn't require authentication.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Retrieval Method", selection: $artworkGetter) {
                        Text("Library").tag(ArtworkGetter.library)
                        Text("Metadata").tag(ArtworkGetter.metadata)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Artwork")
                } footer: {
                    Text("Library searches for cover files in the song's directory. Metadata extracts artwork from the song file, but is slower.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            #endif
        }
    }

    private func saveServer() async {
        let updatedServer = Server(
            id: server?.id ?? UUID(),
            name: name,
            host: host,
            port: port,
            password: password,
            artworkGetter: artworkGetter,
        )

        if isNew {
            serverManager.add(updatedServer)
            serverManager.select(updatedServer)
        } else {
            serverManager.update(updatedServer)
        }

        // Reconnect if this is the selected server
        if serverManager.selectedServerID == updatedServer.id {
            await mpd.reinitialize()
        }

        dismiss()
    }
}
