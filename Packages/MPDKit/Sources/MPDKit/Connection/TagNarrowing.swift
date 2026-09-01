//
//  TagNarrowing.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

/// Restricting responses to the tags that are actually read.
///
/// By default a server sends every tag it holds for every song. A library
/// query answers with thousands of songs at once, and most of those tags —
/// the MusicBrainz identifiers above all, at 36 characters apiece — are
/// parsed into nothing. The `tagtypes` command sets a per-connection mask
/// over what the server sends, so a query can ask for just the tags its
/// result type reads.
///
/// The mask covers responses only: filter clauses and `sort` arguments match
/// against the server's own copy of a song, so narrowing never changes which
/// songs come back or in what order.
extension ConnectionManager {
    /// Wraps `command` so the server sends back only `tags`.
    ///
    /// The mask is set and restored inside the same command list as the query
    /// itself, so it costs no extra round trip and cannot leak into a later
    /// command on a long-lived connection. A server abandons a command list
    /// at its first error, though, so a caller whose query fails has to
    /// restore the mask itself, see ``query(_:as:indexed:)``.
    ///
    /// - Parameters:
    ///   - command: The query to narrow.
    ///   - tags: The tag types the caller reads.
    /// - Returns: The commands to run, which is `command` alone when
    ///            narrowing would gain nothing.
    func narrowing(_ command: String, to tags: Set<TagType>) async -> [String] {
        narrowing(command, to: tags, available: await availableTags())
    }

    /// Wraps `command` so the server sends back only those of `tags` that
    /// `available` says the server knows about.
    ///
    /// - Parameters:
    ///   - command: The query to narrow.
    ///   - tags: The tag types the caller reads.
    ///   - available: The tag identifiers the server supports.
    /// - Returns: The commands to run, which is `command` alone when the
    ///            server would be asked for everything it has anyway, or when
    ///            the supported set could not be established.
    nonisolated func narrowing(_ command: String, to tags: Set<TagType>,
                               available: Set<String>) -> [String]
    {
        let wanted = tags.filter { available.contains($0.identifier) }

        guard !wanted.isEmpty, wanted.count < available.count else {
            return [command]
        }

        let names = wanted.map(\.rawValue).sorted().joined(separator: " ")

        return ["tagtypes clear", "tagtypes enable \(names)", command,
                "tagtypes all"]
    }

    /// The tag types the server supports, as lower-cased identifiers.
    ///
    /// A bare `tagtypes` on a connection that has not masked anything reports
    /// the server's full set, honouring whatever its `metadata_to_use` allows.
    /// Intersecting against it keeps `tagtypes enable` from ever naming a tag
    /// the server would reject, whether because it predates that tag or
    /// because it only speaks part of the protocol.
    ///
    /// The answer is cached for the selected server rather than per
    /// connection, since command-mode connections last a single operation and
    /// would otherwise each pay a round trip to ask the same question.
    ///
    /// - Returns: The supported tag identifiers, or an empty set if the
    ///            server would not say, which disables narrowing.
    private func availableTags() async -> Set<String> {
        if let cached = ConnectionConfiguration.availableTags {
            return cached
        }

        guard let lines = try? await run(["tagtypes"]) else {
            return []
        }

        var identifiers: Set<String> = []
        for line in lines where line != "OK" {
            guard let (key, value) = try? parseLine(line), key == "tagtype"
            else {
                continue
            }

            identifiers.insert(value.lowercased())
        }

        guard !identifiers.isEmpty else {
            return []
        }

        ConnectionConfiguration.availableTags = identifiers

        return identifiers
    }
}
