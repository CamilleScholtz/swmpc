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
        #expect(!ProtocolVersion.isAtLeast("0.19", in: nil))
    }

    @Test("A version is at least itself, however it is spelled")
    func equalVersions() {
        #expect(ProtocolVersion.isAtLeast("0.19", in: "0.19"))
        #expect(ProtocolVersion.isAtLeast("0.19", in: "0.19.0"))
    }

    @Test("Components compare numerically, not lexically")
    func numericComparison() {
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.23"))
        #expect(!ProtocolVersion.isAtLeast("0.21", in: "0.9"))
        #expect(ProtocolVersion.isAtLeast("0.22.4", in: "0.23"))
        #expect(!ProtocolVersion.isAtLeast("0.22.4", in: "0.22"))
        #expect(ProtocolVersion.isAtLeast("0.22.4", in: "0.22.4"))
    }

    @Test("Mopidy's announced version clears the floor but nothing above it")
    func mopidy() {
        let mopidy = "0.19.0"

        #expect(ProtocolVersion.isAtLeast(ProtocolVersion.minimum, in: mopidy))
        #expect(!ProtocolVersion.isAtLeast(
            ProtocolFeature.filterExpressions.minimumVersion, in: mopidy,
        ))
        #expect(!ProtocolVersion.isAtLeast(
            ProtocolFeature.albumArt.minimumVersion, in: mopidy,
        ))
    }
}

@Suite("Query dialects")
struct QueryDialectTests {
    /// A manager pinned to a server version, with no connection behind it.
    private func manager(_ version: String) -> ConnectionManager<CommandMode> {
        ConnectionManager<CommandMode>(version: version)
    }

    @Test("MPD 0.21 and later get filter expressions")
    func modernFilters() async {
        let connection = manager("0.24")

        #expect(await connection.filters([(key: "album", value: "Kid A")])
            == "\"(album == 'Kid A')\"")
        #expect(await connection.filters([(key: "album", value: "Kid A"),
                                          (key: "albumartist", value: "Radiohead")])
            == "\"((album == 'Kid A') AND (albumartist == 'Radiohead'))\"")
    }

    @Test("Older servers get tag/value pairs joined by an implicit AND")
    func legacyFilters() async {
        let connection = manager("0.19.0")

        #expect(await connection.filters([(key: "album", value: "Kid A")])
            == "album \"Kid A\"")
        #expect(await connection.filters([(key: "album", value: "Kid A"),
                                          (key: "albumartist", value: "Radiohead")])
            == "album \"Kid A\" albumartist \"Radiohead\"")
    }

    @Test("Both dialects escape quotes in values")
    func filterEscaping() async {
        #expect(await manager("0.24").filters([(key: "album", value: "Rock 'n' Roll")])
            == "\"(album == 'Rock \\\\'n\\\\' Roll')\"")
        #expect(await manager("0.19.0").filters([(key: "album", value: "Say \"Yes\"")])
            == "album \"Say \\\"Yes\\\"\"")
    }

    @Test("Sorting is asked of the server only from 0.21")
    func sortSupport() async {
        let descriptor = SortDescriptor(option: .album)

        #expect(await manager("0.21").sortSuffix(descriptor) == " sort albumsort")
        #expect(await manager("0.19.0").sortSuffix(descriptor) == "")
    }

    @Test("Descending sorts carry the minus prefix")
    func sortDirection() async {
        let descriptor = SortDescriptor(option: .album, direction: .descending)

        #expect(await manager("0.24").sortSuffix(descriptor) == " sort -albumsort")
    }

    @Test("Sorting by song title waits for the TitleSort tag in 0.24")
    func titleSortTag() async {
        let descriptor = SortDescriptor(option: .song)

        #expect(await manager("0.24").sortSuffix(descriptor) == " sort titlesort")
        #expect(await manager("0.23").sortSuffix(descriptor) == "")
        #expect(await manager("0.23").sortSuffix(SortDescriptor(option: .artist))
            == " sort albumartistsort")
    }

    @Test("Raw tag sorts follow the same floor")
    func rawTagSort() async {
        #expect(await manager("0.21").sortSuffix(tag: "date") == " sort date")
        #expect(await manager("0.19.0").sortSuffix(tag: "date") == "")
    }

    @Test("Artwork commands are gated on the version that introduced them")
    func artworkFeatures() async {
        #expect(await !manager("0.19.0").supports(.albumArt))
        #expect(await manager("0.21").supports(.albumArt))
        #expect(await !manager("0.21").supports(.readPicture))
        #expect(await manager("0.22").supports(.readPicture))
        #expect(await !manager("0.22").supports(.binaryLimit))
        #expect(await manager("0.22.4").supports(.binaryLimit))
    }
}
