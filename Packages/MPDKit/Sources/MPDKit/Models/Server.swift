//
//  Server.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import Foundation

/// Represents a saved MPD server configuration.
public nonisolated struct Server: Identifiable, Hashable, Sendable, Codable {
    public var id = UUID()

    public var name = ""
    public var host = "localhost"
    public var port = 6600
    public var password = ""
    public var artworkGetter = ArtworkGetter.libraryThenMetadata
    public var streamingPort: Int?

    /// Display name for the server, falling back to host if name is empty.
    public var displayName: String {
        name.isEmpty ? host : name
    }

    /// Constructs the full stream URL for this server.
    public var streamURL: URL? {
        guard let streamingPort else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = streamingPort
        components.path = "/"

        return components.url
    }

    /// Creates a new server configuration.
    public init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "localhost",
        port: Int = 6600,
        password: String = "",
        artworkGetter: ArtworkGetter = .libraryThenMetadata,
        streamingPort: Int? = nil,
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.password = password
        self.artworkGetter = artworkGetter
        self.streamingPort = streamingPort
    }
}
