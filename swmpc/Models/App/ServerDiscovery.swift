//
//  ServerDiscovery.swift
//  swmpc
//
//  Created by Camille Scholtz on 30/11/2025.
//

import Network
import Observation

/// Discovers MPD servers on the local network using Bonjour.
///
/// MPD servers advertise themselves via Zeroconf using the `_mpd._tcp` service
/// type when configured with `zeroconf_enabled "yes"` in mpd.conf.
@Observable
final class ServerDiscovery {
    /// A discovered MPD server on the local network.
    struct Server: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let endpoint: Bonjour.Endpoint

        /// Creates a server from a Bonjour endpoint, parsing the display name.
        init(endpoint: Bonjour.Endpoint) {
            self.endpoint = endpoint
            self.id = endpoint.description

            // Parse the Bonjour service name to get a friendly display name.
            // Format: "Service\032Name._mpd._tcp.local." where \032 is space
            // and \. is an escaped dot within the service name.
            var displayName = endpoint.description

            // Remove the service type and domain suffix
            if let range = displayName.range(of: "._mpd._tcp") {
                displayName = String(displayName[..<range.lowerBound])
            }

            // Unescape Bonjour encoding: \032 -> space, \. -> .
            displayName = displayName
                .replacingOccurrences(of: "\\032", with: " ")
                .replacingOccurrences(of: "\\.", with: ".")

            self.name = displayName
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: Server, rhs: Server) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// The list of discovered MPD servers.
    private(set) var servers: [Server] = []

    /// Whether the browser is currently active.
    private(set) var isSearching = false

    /// The background task running the browser.
    @ObservationIgnored private var browseTask: Task<Void, Never>?

    /// Starts browsing for MPD servers on the local network.
    ///
    /// This method launches a background task that continuously monitors
    /// for MPD servers using Bonjour discovery. The `servers` array is
    /// updated automatically as servers appear and disappear.
    func startBrowsing() {
        guard browseTask == nil else { return }

        isSearching = true
        browseTask = Task { [weak self] in
            await self?.browse()
        }
    }

    /// Stops browsing for MPD servers.
    func stopBrowsing() {
        browseTask?.cancel()
        browseTask = nil
        isSearching = false
    }

    /// The main browsing loop using NetworkBrowser.
    private func browse() async {
        let browser = NetworkBrowser(for: .bonjour("_mpd._tcp"))

        do {
            try await browser.run { [weak self] endpoints in
                guard let self, !Task.isCancelled else {
                    return .finish(())
                }

                self.servers = endpoints.map { Server(endpoint: $0) }

                return .continue
            }
        } catch {
            // Browser was cancelled or failed
        }

        isSearching = false
    }
}
