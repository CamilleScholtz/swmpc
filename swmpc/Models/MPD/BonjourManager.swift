//
//  BonjourManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 30/11/2025.
//

import Network
import SwiftUI

/// Represents a discovered MPD server on the local network.
nonisolated struct DiscoveredServer: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let host: String
    let port: Int

    var displayName: String {
        name.isEmpty ? host : name
    }
}

/// Manages Bonjour discovery of MPD servers on the local network.
///
/// Uses the Network framework's `NetworkBrowser` to discover MPD services
/// advertised via Bonjour (`_mpd._tcp`). Discovered services are resolved to
/// obtain their host and port for connection.
@Observable final class BonjourManager {
    /// The list of discovered MPD servers on the local network.
    private(set) var servers: [DiscoveredServer] = []

    /// Indicates whether a network scan is currently in progress.
    private(set) var isScanning = false

    /// The active browse task.
    ///
    /// Marked as `nonisolated(unsafe)` to allow cancellation in deinit.
    /// All other access occurs on the MainActor.
    @ObservationIgnored private nonisolated(unsafe) var browseTask: Task<Void, Never>?

    /// Duration in seconds to scan for servers before stopping.
    private let scanDuration: UInt64 = 5

    /// Starts scanning for MPD servers on the local network.
    ///
    /// Cancels any existing scan, clears previous results, and starts a new
    /// Bonjour browse operation. The scan runs for `scanDuration` seconds
    /// before automatically stopping. Results are accumulated in `servers`.
    ///
    /// Does nothing if a scan is already in progress.
    func scan() {
        guard !isScanning else {
            return
        }

        browseTask?.cancel()
        servers = []

        browseTask = Task {
            await performScan()
        }
    }

    /// Performs the actual Bonjour browsing operation.
    ///
    /// Runs a `NetworkBrowser` for MPD services and resolves discovered
    /// endpoints to obtain their host addresses and ports. The operation is
    /// bounded by `scanDuration` seconds using a racing task group.
    private func performScan() async {
        isScanning = true
        defer { isScanning = false }

        let browser = NetworkBrowser(for: .bonjour("_mpd._tcp"))

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Task.sleep(for: .seconds(self.scanDuration))
                }

                group.addTask {
                    try await browser.run { [weak self] endpoints in
                        guard let self else {
                            return .finish(())
                        }

                        await processEndpoints(endpoints)
                        return .continue
                    }
                }

                try await group.next()
                group.cancelAll()
            }
        } catch {
            // Expected when scan times out or is cancelled.
        }
    }

    /// Processes discovered Bonjour endpoints and updates the servers list.
    ///
    /// Resolves all endpoints in parallel and only updates `servers` if the
    /// set of discovered servers has changed.
    ///
    /// - Parameter endpoints: The currently discovered Bonjour endpoints.
    private func processEndpoints(_ endpoints: [Bonjour.Endpoint]) async {
        let discovered = await withTaskGroup(of: DiscoveredServer?.self) { group in
            for endpoint in endpoints {
                group.addTask {
                    await self.resolveEndpoint(endpoint)
                }
            }

            var results: [DiscoveredServer] = []
            for await server in group {
                if let server {
                    results.append(server)
                }
            }

            return results
        }

        if Set(servers) != Set(discovered) {
            servers = discovered
        }
    }

    /// Resolves a Bonjour endpoint to obtain its host and port.
    ///
    /// Creates a temporary connection to the Bonjour service endpoint to
    /// trigger DNS resolution. Once the connection path is available, extracts
    /// the resolved host and port information.
    ///
    /// - Parameter endpoint: The Bonjour endpoint to resolve.
    /// - Returns: A `DiscoveredServer` with resolved host/port, or `nil` if
    ///            resolution fails or times out.
    private func resolveEndpoint(_ endpoint: Bonjour.Endpoint) async
        -> DiscoveredServer?
    {
        let nwEndpoint = endpoint.nwEndpoint

        return await withTaskGroup(of: DiscoveredServer?.self) { group in
            group.addTask {
                await self.performResolution(
                    nwEndpoint: nwEndpoint,
                    name: endpoint.name,
                    id: endpoint.id,
                )
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    /// Performs the actual connection-based resolution.
    ///
    /// Tries IPv4 first, falls back to IPv6 if IPv4 resolution fails.
    private nonisolated func performResolution(
        nwEndpoint: NWEndpoint,
        name: String,
        id: String,
    ) async -> DiscoveredServer? {
        if let server = await resolveWithIPVersion(
            nwEndpoint: nwEndpoint,
            name: name,
            id: id,
            version: .v4,
        ) {
            return server
        }

        return await resolveWithIPVersion(
            nwEndpoint: nwEndpoint,
            name: name,
            id: id,
            version: .v6,
        )
    }

    /// Resolves an endpoint using a specific IP version.
    private nonisolated func resolveWithIPVersion(
        nwEndpoint: NWEndpoint,
        name: String,
        id: String,
        version: NWProtocolIP.Options.Version,
    ) async -> DiscoveredServer? {
        await withCheckedContinuation { continuation in
            let parameters = NWParameters.tcp

            if let ipOptions = parameters.defaultProtocolStack.internetProtocol
                as? NWProtocolIP.Options
            {
                ipOptions.version = version
            }

            let connection = NWConnection(to: nwEndpoint, using: parameters)
            let resolver = ResolutionState()

            connection.stateUpdateHandler = { [weak connection] state in
                guard resolver.tryComplete() else {
                    return
                }

                switch state {
                case .ready:
                    if let remoteEndpoint = connection?.currentPath?
                        .remoteEndpoint
                    {
                        let server = self.extractServerInfo(
                            from: remoteEndpoint,
                            name: name,
                            id: id,
                        )

                        connection?.cancel()
                        continuation.resume(returning: server)
                    } else {
                        connection?.cancel()
                        continuation.resume(returning: nil)
                    }
                case .failed, .cancelled:
                    continuation.resume(returning: nil)
                default:
                    // Not a terminal state, allow future callbacks.
                    resolver.reset()
                }
            }

            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    /// Thread-safe state tracker for resolution completion.
    private final nonisolated class ResolutionState: @unchecked Sendable {
        private let lock = NSLock()
        private var completed = false

        /// Attempts to mark the resolution as complete.
        /// - Returns: `true` if this call successfully completed the resolution,
        ///            `false` if it was already completed.
        func tryComplete() -> Bool {
            lock.lock()
            defer { lock.unlock() }

            guard !completed else {
                return false
            }

            completed = true
            return true
        }

        /// Resets the state for non-terminal states.
        func reset() {
            lock.lock()
            defer { lock.unlock() }
            completed = false
        }
    }

    /// Extracts server information from a resolved network endpoint.
    ///
    /// Prefers IPv4 addresses, falls back to IPv6 if unavailable.
    ///
    /// - Parameters:
    ///   - endpoint: The resolved `NWEndpoint` containing host/port info.
    ///   - name: The Bonjour service name.
    ///   - id: The unique identifier for the endpoint.
    /// - Returns: A `DiscoveredServer` if an IP address can be extracted,
    ///            or `nil` otherwise.
    private nonisolated func extractServerInfo(
        from endpoint: NWEndpoint,
        name: String,
        id: String,
    ) -> DiscoveredServer? {
        switch endpoint {
        case let .hostPort(host, port):
            let hostString: String
            switch host {
            case let .ipv4(address):
                hostString = stripInterfaceScope(from: "\(address)")
            case let .ipv6(address):
                hostString = stripInterfaceScope(from: "\(address)")
            default:
                return nil
            }

            return DiscoveredServer(
                id: id,
                name: name,
                host: hostString,
                port: Int(port.rawValue),
            )
        default:
            return nil
        }
    }

    /// Strips the interface scope suffix (e.g., "%en0") from an IP address.
    private nonisolated func stripInterfaceScope(from address: String) -> String {
        if let percentIndex = address.firstIndex(of: "%") {
            return String(address[..<percentIndex])
        }
        return address
    }

    nonisolated deinit {
        browseTask?.cancel()
    }
}
