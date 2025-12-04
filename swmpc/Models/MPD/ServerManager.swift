//
//  ServerManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/12/2025.
//

import Foundation

/// Represents a saved MPD server configuration.
nonisolated struct Server: Identifiable, Hashable, Sendable, Codable {
    var id = UUID()

    var name = ""
    var host = "localhost"
    var port = 6600
    var password = ""
    var artworkGetter = ArtworkGetter.library

    /// Display name for the server, falling back to host if name is empty.
    var displayName: String {
        name.isEmpty ? host : name
    }
}

extension Server {
    /// Creates a server from a discovered Bonjour server.
    init(from discovered: DiscoveredServer) {
        self.init()

        name = discovered.name
        host = discovered.host
        port = discovered.port
    }
}

/// Manages the list of saved MPD server configurations.
///
/// Handles persistence of server configurations to UserDefaults and tracks the
/// currently selected server. Changes to the server list or selection are
/// automatically persisted.
@Observable final class ServerManager {
    /// All saved server configurations.
    private(set) var servers: [Server] = []

    /// The ID of the currently selected server.
    var selectedServerID: UUID? {
        didSet {
            if let id = selectedServerID {
                UserDefaults.standard.set(id.uuidString, forKey:
                    Setting.selectedServerID)
            } else {
                UserDefaults.standard.removeObject(forKey:
                    Setting.selectedServerID)
            }

            syncSelectedServer()
        }
    }

    /// The currently selected server, if any.
    var selectedServer: Server? {
        guard let id = selectedServerID else {
            return nil
        }

        return servers.first { $0.id == id }
    }

    init() {
        load()
    }

    /// Adds a new server to the list and persists the change.
    func add(_ server: Server) {
        servers.append(server)
        save()
    }

    /// Updates an existing server and persists the change.
    func update(_ server: Server) {
        guard let index = servers.firstIndex(where: { $0.id
                == server.id
        }) else {
            return
        }

        servers[index] = server
        save()

        if selectedServerID == server.id {
            syncSelectedServer()
        }
    }

    /// Removes a server from the list and persists the change.
    ///
    /// If the removed server was selected, the selection is cleared.
    func remove(_ server: Server) {
        servers.removeAll { $0.id == server.id }
        if selectedServerID == server.id {
            selectedServerID = nil
        }

        save()
    }

    /// Removes servers at the specified offsets.
    func remove(atOffsets offsets: IndexSet) {
        let removedIDs = offsets.map { servers[$0].id }
        servers.remove(atOffsets: offsets)
        if let selectedID = selectedServerID, removedIDs.contains(selectedID) {
            selectedServerID = nil
        }

        save()
    }

    /// Selects a server by its ID.
    func select(_ server: Server?) {
        selectedServerID = server?.id
    }

    /// Loads the server list and selection from UserDefaults.
    private func load() {
        if let data = UserDefaults.standard.data(forKey: Setting.servers),
           let decoded = try? JSONDecoder().decode([Server].self, from: data)
        {
            servers = decoded
        }

        if let idString = UserDefaults.standard.string(forKey:
            Setting.selectedServerID),
            let id = UUID(uuidString: idString)
        {
            selectedServerID = id
        }

        syncSelectedServer()
    }

    /// Persists the server list to UserDefaults.
    private func save() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: Setting.servers)
        }
    }

    /// Updates the shared connection configuration with the selected server.
    private func syncSelectedServer() {
        ConnectionConfiguration.server = selectedServer
    }
}
