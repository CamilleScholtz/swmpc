//
//  Output.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import Foundation

/// Represents an MPD output device.
///
/// Outputs are audio destinations that MPD can send audio to, such as speakers,
/// files, or HTTP streams. Each output has a unique ID, name, and plugin type.
public nonisolated struct Output: Identifiable, Equatable, Hashable, Sendable {
    /// The unique identifier for this output.
    public let id: Int

    /// The display name of the output.
    public let name: String

    /// The plugin type (e.g., "alsa", "pulse", "httpd").
    public let plugin: String

    /// Whether the output is currently enabled.
    public let isEnabled: Bool

    /// Additional attributes for this output.
    public let attributes: [String: String]

    /// Whether this output is an HTTP streaming output.
    public var isHttpd: Bool {
        plugin == "httpd"
    }

    /// Creates a new output from parsed MPD response fields.
    ///
    /// Attributes are passed separately because the server sends one
    /// `attribute: NAME=VALUE` line per attribute, which a field map keyed by
    /// response key cannot hold more than one of, see
    /// ``ConnectionManager/getOutputs()``.
    ///
    /// - Parameters:
    ///   - fields: Dictionary of parsed key-value pairs from MPD response.
    ///             Keys should be lowercased (as returned by `parseLine`).
    ///   - attributes: The output's attributes, keyed by name.
    /// - Returns: An `Output` if required fields are present, nil otherwise.
    public init?(_ fields: [String: String],
                 attributes: [String: String] = [:])
    {
        guard let idString = fields["outputid"],
              let id = Int(idString),
              let name = fields["outputname"],
              let plugin = fields["plugin"]
        else {
            return nil
        }

        self.id = id
        self.name = name
        self.plugin = plugin
        self.attributes = attributes
        isEnabled = fields["outputenabled"] == "1"
    }

    /// Creates a new output.
    /// - Parameters:
    ///   - id: The unique identifier for this output.
    ///   - name: The display name of the output.
    ///   - plugin: The plugin type.
    ///   - isEnabled: Whether the output is currently enabled.
    ///   - attributes: Additional attributes for this output.
    public init(
        id: Int,
        name: String,
        plugin: String,
        isEnabled: Bool,
        attributes: [String: String] = [:],
    ) {
        self.id = id
        self.name = name
        self.plugin = plugin
        self.isEnabled = isEnabled
        self.attributes = attributes
    }
}
