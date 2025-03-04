//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import LaunchAtLogin
import SFSafeSymbols
import SwiftUI

enum Setting {
    static let host = "host"
    static let port = "port"

    static let openAIToken = "openai_token"
    static let deepSeekToken = "deepseek_token"

    static let showStatusBar = "show_status_bar"
    static let showStatusbarSong = "show_statusbar_song"
    static let scrollToCurrent = "scroll_to_current"

    static let artworkGetter = "artwork_getter"
}

struct SettingsView: View {
    enum SettingCategory: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case advanced = "Advanced"

        var id: Self { self }
        var title: String { rawValue }

        var image: SFSymbol {
            switch self {
            case .general: .gearshape
            case .appearance: .paintpalette
            case .advanced: .gearshape2
            }
        }

        var view: AnyView {
            switch self {
            case .general:
                AnyView(GeneralView())
            case .appearance:
                AnyView(AppearanceView())
            case .advanced:
                AnyView(AdvancedView())
            }
        }
    }

    @State private var selection: SettingCategory? = .general

    var body: some View {
        TabView(selection: $selection) {
            ForEach(SettingCategory.allCases) { category in
                category.view
                    .tabItem {
                        Label(category.title, systemSymbol: category.image)
                    }
                    .tag(category)
                    .padding(40)
            }
        }
        .frame(width: 500)
    }
}

struct GeneralView: View {
    @AppStorage(Setting.host) var host = "localhost"
    @AppStorage(Setting.port) var port = 6600

    @AppStorage(Setting.openAIToken) var openAIToken = ""
    @AppStorage(Setting.deepSeekToken) var deepSeekToken = ""

    var body: some View {
        Form {
            Section {
                TextField("MPD Host:", text: $host)
                TextField("MPD Port:", value: $port, formatter: NumberFormatter())
            }

            Divider()

            Section {
                LaunchAtLogin.Toggle()
            }

            Divider()

            Section {
                TextField("OpenAI Token:", text: $openAIToken)
                    .textContentType(.password)
                Text("This is required to use the OpenAI API.")
                    .font(.caption2)
            }
        }
        .navigationTitle("General")
    }
}

struct AppearanceView: View {
    @AppStorage(Setting.showStatusBar) var showStatusBar = true
    @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true
    @AppStorage(Setting.scrollToCurrent) var scrollToCurrent = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $scrollToCurrent) {
                    Text("Scroll to Current Song")
                    Text("Scroll to the current song when the song changes.")
                }
            }

            Section {
                Toggle("Show in Status Bar", isOn: $showStatusBar)
                Toggle(isOn: $showStatusbarSong) {
                    Text("Show Song in Status Bar")
                    Text("If this is disabled, only the swmpc icon will be shown.")
                }
                .disabled(!showStatusBar)
            }
        }
        .navigationTitle("Appearance")
    }
}

struct AdvancedView: View {
    @AppStorage(Setting.artworkGetter) var artworkGetter = ArtworkGetter.library

    var body: some View {
        Form {
            Section {
                Picker("Artwork method:", selection: $artworkGetter) {
                    Text("Library").tag(ArtworkGetter.library)
                    Text("Embedded").tag(ArtworkGetter.embedded)
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("Advanced")
    }
}
