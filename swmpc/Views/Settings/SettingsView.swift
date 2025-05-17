//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import KeychainStorageKit
import SFSafeSymbols
import SwiftUI

#if os(macOS)
    import LaunchAtLogin
#endif

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

        @State private var password = ""

        @AppStorage(Setting.artworkGetter) var artworkGetter = ArtworkGetter.library
        @AppStorage(Setting.isDemoMode) var isDemoMode = false

        var body: some View {
            Form {
                TextField("MPD Host:", text: $host)
                    .disabled(isDemoMode)
                TextField("MPD Port:", value: $port, formatter: NumberFormatter())
                    .disabled(isDemoMode)

                SecureField("MPD Password:", text: $password)
                    .disabled(isDemoMode)
                    .onAppear {
                        @KeychainStorage(Setting.password) var passwordSecureStorage: String?
                        password = passwordSecureStorage ?? ""
                    }
                    .onChange(of: password) { _, value in
                        @KeychainStorage(Setting.password) var passwordSecureStorage: String?
                        passwordSecureStorage = value.isEmpty ? nil : value
                    }
                Text("Leave empty if no password is set.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()
                    .frame(height: 32, alignment: .center)

                Picker("Artwork retrieval:", selection: $artworkGetter) {
                    Text("Library").tag(ArtworkGetter.library)
                    Text("Embedded").tag(ArtworkGetter.embedded)
                }
                .pickerStyle(.inline)
                .disabled(isDemoMode)
                Text("Library will fetch artwork by searching the directory the file resides in for a file called cover.png, cover.jpg, or cover.webp. Embedded will fetch the artwork from the file itself.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                #if os(macOS)
                    Divider()
                        .frame(height: 32, alignment: .center)

                    LaunchAtLogin.Toggle()
                #endif

                Divider()
                    .frame(height: 32, alignment: .center)

                Toggle(isOn: $isDemoMode) {
                    Text("Demo Mode")
                    Text("When enabled, uses mock data instead of connecting to MPD.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

                #if os(macOS)
                    Divider()
                        .frame(height: 32, alignment: .center)

                    Toggle("Show in Status Bar", isOn: $showStatusBar)
                        .onChange(of: showStatusBar) { _, _ in
                            NotificationCenter.default.post(name: .statusBarSettingChangedNotification, object: nil)
                        }
                    Toggle(isOn: $showStatusbarSong) {
                        Text("Show Song in Status Bar")
                        Text("If this is disabled, only the swmpc icon will be shown.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .disabled(!showStatusBar)
                    .onChange(of: showStatusbarSong) { _, _ in
                        NotificationCenter.default.post(name: .statusBarSettingChangedNotification, object: nil)
                    }
                #endif
            }
            .padding(32)
            .navigationTitle("Behavior")
        }
    }

    struct IntelligenceView: View {
        @AppStorage(Setting.isIntelligenceEnabled) var isIntelligenceEnabled = false
        @AppStorage(Setting.intelligenceModel) var intelligenceModel = IntelligenceModel.openAI

        @State private var token = ""

        var body: some View {
            Form {
                Toggle(isOn: $isIntelligenceEnabled) {
                    Text("Enable AI Features")
                    Text("Currently used for smart playlist generation.")
                }

                Divider()
                    .frame(height: 32, alignment: .center)

                Picker("Model:", selection: $intelligenceModel) {
                    ForEach(IntelligenceModel.allCases.filter(\.isEnabled)) { model in
                        HStack {
                            Text(model.name)
                            Text(model.model)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.inline)
                .disabled(!isIntelligenceEnabled)

                SecureField("API Token:", text: $token)
                    .textContentType(.password)
                    .disabled(!isIntelligenceEnabled)
                    .onAppear {
                        @KeychainStorage(intelligenceModel.setting) var tokenSecureStorage: String?
                        token = tokenSecureStorage ?? ""
                    }
                    .onChange(of: token) { _, value in
                        @KeychainStorage(intelligenceModel.setting) var tokenSecureStorage: String?
                        tokenSecureStorage = value.isEmpty ? nil : value
                    }
                    .onChange(of: intelligenceModel) {
                        @KeychainStorage(intelligenceModel.setting) var tokenSecureStorage: String?
                        token = tokenSecureStorage ?? ""
                    }
            }
            .padding(32)
            .navigationTitle("Intelligence")
        }
    }
}
