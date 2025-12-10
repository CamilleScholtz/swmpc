//
//  ServerEditView.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/12/2025.
//

import ButtonKit
import MPDKit
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

                Divider()

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    if !isNew {
                        Button("Delete") {
                            serverManager.remove(server!)
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }

                    Spacer()

                    AsyncButton("Save") {
                        await saveServer()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(host.isEmpty)
                }
                .padding()
            }
            .frame(width: 450)
        #endif
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                #if os(iOS)
                    .autocapitalization(.words)
                #endif
            } header: {
                Text("Name")
            } footer: {
                Text("Optional display name for this server.")
            }

            Section("Server") {
                TextField("Host", text: $host)
                #if os(iOS)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                #endif
                TextField("Port", value: $port, formatter: NumberFormatter())
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
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
                #if os(iOS)
                .pickerStyle(.navigationLink)
                #elseif os(macOS)
                .pickerStyle(.inline)
                #endif
            } header: {
                Text("Artwork")
            } footer: {
                Text("Library searches for cover files in the song's directory. Metadata extracts artwork from the song file, but is slower.")
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
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

        if serverManager.selectedServerID == updatedServer.id {
            await mpd.reinitialize()
        }

        dismiss()
    }
}
