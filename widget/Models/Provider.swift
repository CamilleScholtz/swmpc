//
//  Provider.swift
//  widget
//
//  Created by Camille Scholtz on 09/12/2025.
//

import MPDKit
import Shared
import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let artwork: PlatformImage?
    let title: String
    let artist: String
}

struct Provider: TimelineProvider {
    private static let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in _: Context) -> NowPlayingEntry {
        NowPlayingEntry(
            date: Date(),
            artwork: nil,
            title: "Not Playing",
            artist: "swmpc",
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        if context.isPreview {
            completion(NowPlayingEntry(
                date: Date(),
                artwork: nil,
                title: "Mad Rush",
                artist: "Philip Glass",
            ))
            return
        }

        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Date().addingTimeInterval(Self.refreshInterval)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchEntry() async -> NowPlayingEntry {
        configureConnection()

        do {
            let statusData = try await ConnectionManager.command {
                try await $0.getStatusData()
            }

            let title = statusData.song?.title ?? "Not Playing"
            let artist = statusData.song?.artist ?? "swmpc"

            var artwork: PlatformImage?
            if let file = statusData.song?.file {
                if let data = try? await ConnectionManager.artwork({
                    try await $0.getArtworkData(for: file)
                }) {
                    artwork = PlatformImage(data: data)
                }
            }

            return NowPlayingEntry(
                date: Date(),
                artwork: artwork,
                title: title,
                artist: artist,
            )
        } catch {
            return NowPlayingEntry(
                date: Date(),
                artwork: nil,
                title: "Not Playing",
                artist: "swmpc",
            )
        }
    }

    private func configureConnection() {
        guard let config = WidgetServerConfig.load() else {
            return
        }

        ConnectionConfiguration.server = Server(
            host: config.host,
            port: config.port,
            password: config.password ?? "",
        )
    }
}
