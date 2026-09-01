//
//  ConnectionTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

import Foundation
import Testing

@testable import MPDKit

@Suite("Command guards")
struct CommandGuardTests {
    @Test("An empty command list is never sent")
    func emptyList() async throws {
        let connection = ConnectionManager<CommandMode>()
        let lines = try await connection.run([])

        #expect(lines.isEmpty)
        #expect(await connection.isCommandInFlight == false)
    }

    @Test("A command without a connection reports the connection is gone")
    func withoutConnection() async {
        let connection = ConnectionManager<CommandMode>()

        await #expect(throws: ConnectionManagerError
            .connectionUnexpectedClosure)
        {
            try await connection.run(["status"])
        }
    }

    @Test("A failed command does not leave the connection marked as busy")
    func releasesAfterFailure() async {
        let connection = ConnectionManager<CommandMode>()

        _ = try? await connection.run(["status"])

        #expect(await connection.isCommandInFlight == false)

        _ = try? await connection.run(["status"])

        #expect(await connection.isCommandInFlight == false)
    }

    @Test("Nothing is in flight on a fresh connection")
    func freshConnection() async {
        let connection = ConnectionManager<CommandMode>()

        #expect(await connection.isCommandInFlight == false)
        #expect(await connection.isIdlePending == false)
        #expect(await connection.version == nil)
    }
}

@Suite("Buffered reads")
struct BufferedReadTests {
    @Test("A read of nothing needs no connection and returns nothing")
    func zeroLength() async throws {
        let connection = ConnectionManager<CommandMode>()
        let data = try await connection.readFixedLengthData(0)

        #expect(data.isEmpty)
    }

    @Test("A negative length is malformed rather than a hung read")
    func negativeLength() async {
        let connection = ConnectionManager<CommandMode>()

        await #expect(throws: ConnectionManagerError.self) {
            try await connection.readFixedLengthData(-1)
        }
    }

    @Test("A read that needs bytes off a dead connection gives up")
    func withoutConnection() async {
        let connection = ConnectionManager<CommandMode>()

        await #expect(throws: ConnectionManagerError
            .connectionUnexpectedClosure)
        {
            try await connection.readFixedLengthData(1)
        }
    }
}

@Suite("Connection lifecycle")
struct ConnectionLifecycleTests {
    @Test("Disconnecting a connection that never opened is harmless")
    func disconnectWithoutConnection() async {
        let connection = ConnectionManager<CommandMode>()

        await connection.disconnect()

        #expect(await connection.version == nil)
    }

    @Test("Disconnecting forgets the version the greeting reported")
    func disconnectForgetsVersion() async {
        let connection = ConnectionManager<CommandMode>(version: "0.24")

        #expect(await connection.isVersionAtLeast("0.24"))

        await connection.disconnect()

        #expect(await connection.version == nil)
        #expect(await connection.isVersionAtLeast("0.21") == false)
    }

    @Test("Probing an idle connection with nothing parked succeeds at once")
    func probeWithoutIdle() async {
        #expect(await ConnectionManager<IdleMode>().probe())
    }
}
