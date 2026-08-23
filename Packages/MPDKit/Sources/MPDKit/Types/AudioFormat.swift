//
//  AudioFormat.swift
//  MPDKit
//
//  Created by Camille Scholtz on 23/08/2026.
//

/// Represents the audio format MPD is currently decoding.
///
/// MPD reports this as a `sampleRate:bits:channels` triplet, in which any
/// field may be a placeholder such as `*` or `0` when it is unknown, and in
/// which `bits` is `dsd` for DSD sources.
public nonisolated struct AudioFormat: Equatable, Hashable, Sendable {
    /// The sample rate in hertz.
    public let sampleRate: Int?

    /// The bit depth, or nil for sources without one, such as DSD.
    public let bits: Int?

    /// The number of channels.
    public let channels: Int?

    /// Creates an audio format from MPD's `sampleRate:bits:channels` value.
    ///
    /// - Parameter value: The raw `audio` field of an MPD status response.
    /// - Returns: An `AudioFormat`, or nil if none of the fields could be
    ///            parsed.
    public init?(_ value: String) {
        let fields = value.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == 3 else {
            return nil
        }

        sampleRate = Self.parse(fields[0])
        bits = Self.parse(fields[1])
        channels = Self.parse(fields[2])

        if sampleRate == nil, bits == nil, channels == nil {
            return nil
        }
    }

    /// Parses a single field, treating zero and placeholders as unknown.
    private static func parse(_ field: Substring) -> Int? {
        Int(field).flatMap { $0 > 0 ? $0 : nil }
    }
}
