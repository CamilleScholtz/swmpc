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

/// Manages Bonjour discovery for MPD servers on the local network.
///
/// Uses Network.framework's `NetworkBrowser` to discover MPD services
/// advertised via the `_mpd._tcp` Bonjour service type. The manager handles
/// endpoint resolution to obtain usable host/port pairs from discovered
/// services.
@Observable final class BonjourManager {
    /// The list of discovered MPD servers on the local network.
    private(set) var servers: [DiscoveredServer] = []

    /// Indicates whether a network scan is currently in progress.
    private(set) var isScanning = false

    /// The most recent error encountered during scanning, if any.
    private(set) var error: Error?

    @ObservationIgnored private var browseTask: Task<Void, Never>?

    /// Duration in seconds to scan for servers before stopping.
    private let scanDuration: UInt64 = 5

    deinit {
        browseTask?.cancel()
    }

    /// Initiates a scan for MPD servers on the local network.
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
        isScanning = true
        error = nil

        browseTask = Task {
            await browse()
        }
    }

    /// Performs the actual Bonjour browse operation.
    ///
    /// Runs a `NetworkBrowser` for MPD services and resolves discovered
    /// endpoints to obtain their host addresses and ports. The operation is
    /// bounded by `scanDuration` seconds using a racing task group.
    private func browse() async {
        let browser = NetworkBrowser(for: .bonjour("_mpd._tcp"))
            .onStateUpdate { [weak self] _, state in
                Task { @MainActor [weak self] in
                    switch state {
                    case let .failed(error):
                        self?.error = error
                        self?.isScanning = false
                    case let .waiting(error):
                        self?.error = error
                    case .cancelled:
                        self?.isScanning = false
                    default:
                        break
                    }
                }
            }

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

                        let resolved = await withTaskGroup(of:
                            DiscoveredServer?.self)
                        { group in
                            for endpoint in endpoints {
                                group.addTask { await self.resolve(endpoint) }
                            }
                            return await group.reduce(into: [
                                DiscoveredServer
                            ]()) { result, server in
                                if let server { result.append(server) }
                            }
                        }

                        await MainActor.run {
                            if Set(self.servers) != Set(resolved) {
                                self.servers = resolved
                            }
                        }

                        return .continue
                    }
                }

                try await group.next()
                group.cancelAll()
            }
        } catch is CancellationError {
            // Expected when scan times out.
        } catch {
            self.error = error
        }

        isScanning = false
    }

    /// Resolves a Bonjour endpoint to a concrete host and port.
    ///
    /// If the endpoint already contains host/port information, it's returned
    /// directly. For service-type endpoints, a temporary TCP connection is
    /// established to resolve the actual network address. The connection is
    /// cancelled immediately after resolution.
    ///
    /// - Parameter endpoint: The Bonjour endpoint to resolve.
    /// - Returns: A `DiscoveredServer` with resolved host/port, or `nil` if
    ///            resolution fails.
    private func resolve(_ endpoint: Bonjour.Endpoint) async ->
        DiscoveredServer?
    {
        let nwEndpoint = endpoint.nwEndpoint

        if case let .hostPort(host, port) = nwEndpoint {
            return DiscoveredServer(
                id: endpoint.id,
                name: endpoint.name,
                host: host.debugDescription,
                port: Int(port.rawValue),
            )
        }

        guard case .service = nwEndpoint else {
            return nil
        }

        let parameters = NWParameters.tcp
        if let ipOptions = parameters.defaultProtocolStack.internetProtocol
            as? NWProtocolIP.Options
        {
            ipOptions.version = .v4
        }

        let connection = NWConnection(to: nwEndpoint, using: parameters)

        return await withCheckedContinuation { continuation in
            nonisolated(unsafe) var didResume = false

            connection.stateUpdateHandler = { state in
                guard !didResume else {
                    return
                }

                switch state {
                case .ready:
                    didResume = true
                    defer { connection.cancel() }

                    guard let path = connection.currentPath,
                          let remote = path.remoteEndpoint,
                          case let .hostPort(host, port) = remote
                    else {
                        continuation.resume(returning: nil)
                        return
                    }

                    var hostString = host.debugDescription
                    if let i = hostString.firstIndex(of: "%") {
                        hostString = String(hostString[..<i])
                    }

                    continuation.resume(returning: DiscoveredServer(
                        id: endpoint.id,
                        name: endpoint.name,
                        host: hostString,
                        port: Int(port.rawValue),
                    ))
                case .failed, .cancelled:
                    didResume = true
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }
}
