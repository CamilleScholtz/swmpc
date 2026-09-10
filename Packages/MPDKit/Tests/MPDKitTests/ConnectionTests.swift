//
//  ConnectionTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

import Foundation
@testable import MPDKit
import Testing

@Suite("Command guards")
struct CommandGuardTests {
    @Test
    func `An empty command list is never sent`() async throws {
        let connection = ConnectionManager<CommandMode>()
        let lines = try await connection.run([])

        #expect(lines.isEmpty)
        #expect(await connection.isCommandInFlight == false)
    }

    @Test
    func `A command without a connection reports the connection is gone`() async {
        let connection = ConnectionManager<CommandMode>()

        await #expect(throws: ConnectionManagerError
            .connectionUnexpectedClosure)
        {
            try await connection.run(["status"])
        }
    }

    @Test
    func `A failed command does not leave the connection marked as busy`() async {
        let connection = ConnectionManager<CommandMode>()

        _ = try? await connection.run(["status"])

        #expect(await connection.isCommandInFlight == false)

        _ = try? await connection.run(["status"])

        #expect(await connection.isCommandInFlight == false)
    }

    @Test
    func `Nothing is in flight on a fresh connection`() async {
        let connection = ConnectionManager<CommandMode>()

        #expect(await connection.isCommandInFlight == false)
        #expect(await connection.isIdlePending == false)
        #expect(await connection.version == nil)
    }
}

@Suite("Buffered reads")
struct BufferedReadTests {
    @Test
    func `A read of nothing needs no connection and returns nothing`() async throws {
        let connection = ConnectionManager<CommandMode>()
        let data = try await connection.readFixedLengthData(0)

        #expect(data.isEmpty)
    }

    @Test
    func `A negative length is malformed rather than a hung read`() async {
        let connection = ConnectionManager<CommandMode>()

        await #expect(throws: ConnectionManagerError.self) {
            try await connection.readFixedLengthData(-1)
        }
    }

    @Test
    func `A read that needs bytes off a dead connection gives up`() async {
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
    @Test
    func `Disconnecting a connection that never opened is harmless`() async {
        let connection = ConnectionManager<CommandMode>()

        await connection.disconnect()

        #expect(await connection.version == nil)
    }

    @Test
    func `Disconnecting forgets the version the greeting reported`() async {
        let connection = ConnectionManager<CommandMode>(version: "0.24")

        #expect(await connection.isVersionAtLeast("0.24"))

        await connection.disconnect()

        #expect(await connection.version == nil)
        #expect(await connection.isVersionAtLeast("0.21") == false)
    }

    @Test
    func `Probing an idle connection with nothing parked succeeds at once`() async {
        #expect(await ConnectionManager<IdleMode>().probe())
    }
}
