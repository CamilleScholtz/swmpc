//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import KeychainStorageKit
import LaunchAtLogin
import SFSafeSymbols
import SwiftUI

enum Setting {
    static let host = "host"
    static let port = "port"

    static let showStatusBar = "show_status_bar"
    static let showStatusbarSong = "show_statusbar_song"
    static let scrollToCurrent = "scroll_to_current"

    static let isIntelligenceEnabled = "is_intelligence_enabled"
    static let intelligenceModel = "intelligence_model"
    static let deepSeekToken = "deepseek_token"
    static let openAIToken = "openai_token"

    static let artworkGetter = "artwork_getter"
}

struct SettingsView: View {
    enum SettingCategory: String, CaseIterable, Identifiable {
        case general = "General"
        case behavior = "Behavior"
        case intelligence = "Intelligence"

        var id: Self { self }
        var title: String { rawValue }

        var image: SFSymbol {
            switch self {
            case .general: .gearshape
            case .behavior: .sliderHorizontal3
            case .intelligence: .sparkles
            }
        }

        var view: AnyView {
            switch self {
            case .general:
                AnyView(GeneralView())
            case .behavior:
                AnyView(BehaviorView())
            case .intelligence:
                AnyView(IntelligenceView())
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
            }
        }
        .frame(width: 500)
    }

    struct GeneralView: View {
        @AppStorage(Setting.host) var host = "localhost"
        @AppStorage(Setting.port) var port = 6600

        @AppStorage(Setting.artworkGetter) var artworkGetter = ArtworkGetter.library

        var body: some View {
            Form {
                TextField("MPD Host:", text: $host)
                TextField("MPD Port:", value: $port, formatter: NumberFormatter())

                Divider()
                    .frame(height: 32, alignment: .center)

                Picker("Artwork retrieval:", selection: $artworkGetter) {
                    Text("Library").tag(ArtworkGetter.library)
                    Text("Embedded").tag(ArtworkGetter.embedded)
                }
                .pickerStyle(.inline)
                Text("Library will fetch artwork by searching the directory the file resides in for a file called cover.png, cover.jpg, or cover.webp. Embedded will fetch the artwork from the file itself.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()
                    .frame(height: 32, alignment: .center)

                LaunchAtLogin.Toggle()
            }
            .padding(32)
            .navigationTitle("General")
        }
    }

    struct BehaviorView: View {
        @AppStorage(Setting.showStatusBar) var showStatusBar = true
        @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true
        @AppStorage(Setting.scrollToCurrent) var scrollToCurrent = false

        var body: some View {
            Form {
                Toggle(isOn: $scrollToCurrent) {
                    Text("Scroll to Current Song")
                    Text("Scroll to the current song when the song changes.")
                }

                Divider()
                    .frame(height: 32, alignment: .center)

                Toggle("Show in Status Bar", isOn: $showStatusBar)
                Toggle(isOn: $showStatusbarSong) {
                    Text("Show Song in Status Bar")
                    Text("If this is disabled, only the swmpc icon will be shown. A restart is required for these changes to take effect.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(!showStatusBar)
            }
            .padding(32)
            .navigationTitle("Behavior")
        }
    }

    struct IntelligenceView: View {
        @AppStorage(Setting.isIntelligenceEnabled) var isIntelligenceEnabled = false
        @AppStorage(Setting.intelligenceModel) var intelligenceModel = IntelligenceModel.deepSeek

        @State private var deepSeekToken = ""
        @State private var openAIToken = ""

        var body: some View {
            Form {
                Toggle(isOn: $isIntelligenceEnabled) {
                    Text("Enable AI Features")
                    Text("Currently used for smart playlist generation.")
                }

                Divider()
                    .frame(height: 32, alignment: .center)

                Picker("Model:", selection: $intelligenceModel) {
                    Text("DeepSeek").tag(IntelligenceModel.deepSeek)
                    Text("OpenAI").tag(IntelligenceModel.openAI)
                }
                .pickerStyle(.inline)
                .disabled(!isIntelligenceEnabled)

                switch intelligenceModel {
                case .deepSeek:
                    SecureField("API Token:", text: $deepSeekToken)
                        .textContentType(.password)
                        .disabled(!isIntelligenceEnabled)
                        .onAppear {
                            @KeychainStorage(Setting.deepSeekToken) var deepSeekTokenSecureStorage: String?
                            deepSeekToken = deepSeekTokenSecureStorage ?? ""
                        }
                        .onChange(of: deepSeekToken) { _, value in
                            guard !value.isEmpty else {
                                return
                            }

                            @KeychainStorage(Setting.deepSeekToken) var deepSeekTokenSecureStorage: String?
                            deepSeekTokenSecureStorage = value
                        }
                case .openAI:
                    SecureField("API Token:", text: $openAIToken)
                        .textContentType(.password)
                        .disabled(!isIntelligenceEnabled)
                        .onAppear {
                            @KeychainStorage(Setting.openAIToken) var openAITokenSecureStorage: String?
                            openAIToken = openAITokenSecureStorage ?? ""
                        }
                        .onChange(of: openAIToken) { _, value in
                            guard !value.isEmpty else {
                                return
                            }

                            @KeychainStorage(Setting.openAIToken) var openAITokenSecureStorage: String?
                            openAITokenSecureStorage = value
                        }
                }
            }
            .padding(32)
            .navigationTitle("Intelligence")
        }
    }
}
