//
//  ProtocolDialectTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 25/08/2026.
//

import Testing

@testable import MPDKit

@Suite("Protocol version comparison")
struct ProtocolVersionTests {
    @Test("An unknown version supports nothing")
    func unknownVersion() {
        #expect(!ProtocolVersion.isAtLeast("0.21", in: nil))
    }

    @Test("A version is at least itself, however it is spelled")
    func equalVersions() {
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.21"))
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.21.0"))
    }

    @Test("Components compare numerically, not lexically")
    func numericComparison() {
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.23"))
        #expect(!ProtocolVersion.isAtLeast("0.21", in: "0.9"))
        #expect(ProtocolVersion.isAtLeast("0.22.4", in: "0.23"))
        #expect(!ProtocolVersion.isAtLeast("0.22.4", in: "0.22"))
        #expect(ProtocolVersion.isAtLeast("0.22.4", in: "0.22.4"))
    }

    @Test("Servers announcing an older protocol fall below the floor")
    func belowFloor() {
        // Mopidy-MPD announces 0.19; OwnTone announces 0.23.
        #expect(!ProtocolVersion.isAtLeast("0.21", in: "0.19.0"))
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.23.0"))
    }
}

@Suite("Query building")
struct QueryBuildingTests {
    /// A manager pinned to a server version, with no connection behind it.
    private func manager(_ version: String) -> ConnectionManager<CommandMode> {
        ConnectionManager<CommandMode>(version: version)
    }

    @Test("A filter clause is parenthesised, and quoted unless composed")
    func filter() async {
        let connection = manager("0.24")

        #expect(await connection.filter(key: "album", value: "Kid A")
            == "\"(album == 'Kid A')\"")
        #expect(await connection.filter(key: "album", value: "Kid A", quote: false)
            == "(album == 'Kid A')")
    }

    @Test("Quotes in values are escaped")
    func filterEscaping() async {
        #expect(await manager("0.24").filter(key: "album", value: "Rock 'n' Roll")
            == "\"(album == 'Rock \\\\'n\\\\' Roll')\"")
    }

    @Test("Sorts carry the tag, and a minus prefix when descending")
    func sortDirection() async {
        #expect(await manager("0.24").sortSuffix(SortDescriptor(option: .album))
            == " sort albumsort")
        #expect(await manager("0.24").sortSuffix(SortDescriptor(option: .album,
                                                                direction: .descending))
            == " sort -albumsort")
    }

    @Test("Sorting by song title waits for the TitleSort tag in 0.24")
    func titleSortTag() async {
        let descriptor = SortDescriptor(option: .song)

        #expect(await manager("0.24").sortSuffix(descriptor) == " sort titlesort")
        #expect(await manager("0.23").sortSuffix(descriptor) == "")
        #expect(await manager("0.23").sortSuffix(SortDescriptor(option: .artist))
            == " sort albumartistsort")
    }


}
