//
//  WidgetServerConfig.swift
//  Shared
//
//  Created by Camille Scholtz on 09/12/2025.
//

import Foundation

private let appGroupID = "group.com.camille.swmpc"
private let configKey = "widgetServerConfig"

/// Server configuration shared with the widget via App Groups.
public nonisolated struct WidgetServerConfig: Codable, Sendable {
    public let host: String
    public let port: Int
    public let password: String?

    public init(host: String, port: Int, password: String?) {
        self.host = host
        self.port = port
        self.password = password
    }

    public static func save(_ config: WidgetServerConfig) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID,
        ) else {
            return
        }

        let url = container.appendingPathComponent(configKey)
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: url)
        }
    }

    public static func load() -> WidgetServerConfig? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID,
        ),
            let data = try? Data(contentsOf: container.appendingPathComponent(
                configKey,
            ))
        else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetServerConfig.self, from: data)
    }
}
