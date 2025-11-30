//
//  AboutView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2025.
//

import SFSafeSymbols
import SwiftUI

struct AboutView: View {
    @State private var artists: Int?
    @State private var albums: Int?
    @State private var songs: Int?
    @State private var uptime: Int?
    @State private var playtime: Int?
    @State private var update: Int?

    #if os(iOS)
        private static var appIcon: UIImage? {
            guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
                  let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
                  let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
                  let iconName = iconFiles.last
            else {
                return nil
            }

            return UIImage(named: iconName)
        }
    #endif

    var body: some View {
        VStack(spacing: Layout.Spacing.large) {
            VStack(spacing: Layout.Spacing.small) {
                #if os(iOS)
                    if let image = Self.appIcon {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                #elseif os(macOS)
                    if let image = NSApp.applicationIconImage {
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                #endif

                Text("swmpc")
                    .font(.headline)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("Version \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: Layout.Spacing.medium) {
                    Link(destination: URL(string: "https://github.com/CamilleScholtz/swmpc")!) {
                        Label("Website", systemImage: "link")
                            .font(.caption)
                    }

                    Text("·")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Link(destination: URL(string: "https://github.com/CamilleScholtz/swmpc/issues/new?template=bug_report.md")!) {
                        Label("Report Bug", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                    }

                    Text("·")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Link(destination: URL(string: "https://github.com/CamilleScholtz/swmpc/issues/new?template=feature_request.md")!) {
                        Label("Request Feature", systemImage: "lightbulb")
                            .font(.caption)
                    }
                }
                .padding(.top, Layout.Spacing.small)
            }

            Divider()
                .padding(.horizontal)

            VStack(spacing: Layout.Spacing.medium) {
                HStack(spacing: Layout.Spacing.small) {
                    StatCard(symbol: .squareStackFill, label: "Albums", value: albums?.formatted())
                    StatCard(symbol: .musicMicrophone, label: "Artists", value: artists?.formatted())
                    StatCard(symbol: .musicNote, label: "Songs", value: songs?.formatted())
                }

                VStack(alignment: .leading, spacing: Layout.Spacing.small) {
                    StatRow(symbol: .clockFill, label: "Server Uptime", value: uptime.map { Double($0).humanTimeString })
                    StatRow(symbol: .waveform, label: "Total Music Duration", value: playtime.map { Double($0).humanTimeString })
                    StatRow(symbol: .calendarBadgeClock, label: "Last Database Update", value: update.map(formatDate))
                }
                #if os(iOS)
                .frame(maxWidth: .infinity, alignment: .leading)
                #endif
            }
            .padding(.horizontal)

            #if os(iOS)
                Spacer()
            #endif
        }
        .padding(.vertical)
        #if os(iOS)
            .background(Color(.systemGroupedBackground), ignoresSafeAreaEdges: .all)
        #elseif os(macOS)
            .frame(width: 420, height: 420)
        #endif
            .task {
                let data = try? await ConnectionManager.command {
                    try await $0.getStatsData()
                }

                guard let data else {
                    return
                }

                artists = data.artists
                albums = data.albums
                songs = data.songs
                uptime = data.uptime
                playtime = data.playtime
                update = data.update
            }
    }

    struct StatCard: View {
        let symbol: SFSymbol
        let label: String
        let value: String?

        var body: some View {
            VStack(spacing: 8) {
                Image(systemSymbol: symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(.accent)
                    .frame(height: 32)

                Text(value ?? "?")
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)
                    .fill(.background.opacity(0.4)),
            )
        }
    }

    struct StatRow: View {
        let symbol: SFSymbol
        let label: String
        let value: String?

        var body: some View {
            #if os(iOS)
                VStack(alignment: .leading) {
                    HStack(spacing: 12) {
                        Image(systemSymbol: symbol)
                            .font(.system(size: 14))
                            .fontWeight(.semibold)
                            .foregroundStyle(.accent)
                            .frame(width: 20)

                        Text(label)
                            .font(.subheadline)
                    }

                    Text(value ?? "?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
            #elseif os(macOS)
                HStack(spacing: 12) {
                    Image(systemSymbol: symbol)
                        .font(.system(size: 14))
                        .foregroundStyle(.accent)
                        .frame(width: 20)

                    Text(label)
                        .font(.subheadline)

                    Spacer()

                    Text(value ?? "?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
            #endif
        }
    }

    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()

        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter.string(from: date)
    }
}
