//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

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
        @AppStorage(Setting.password) var password = ""

        @AppStorage(Setting.artworkGetter) var artworkGetter = ArtworkGetter.library

        var body: some View {
            Form {
                TextField("MPD Host:", text: $host)
                TextField("MPD Port:", value: $port, formatter: NumberFormatter())

                SecureField("MPD Password:", text: $password)
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
                Text("Library will fetch artwork by searching the directory the songs resides in for a file called cover.png, cover.jpg, or cover.webp. Embedded will fetch the artwork from the song metadata. Using embedded is not recommended as it is generally much slower.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .frame(height: 32, alignment: .center)
            }
            .padding(32)
            .navigationTitle("General")
        }
    }

    struct BehaviorView: View {
        @AppStorage(Setting.showStatusBar) var showStatusBar = true
        @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true
        @AppStorage(Setting.runAsAgent) var runAsAgent = false

        @State private var restartAlertShown = false
        @State private var isRestarting = false

        var body: some View {
            Form {
                #if os(macOS)
                    LaunchAtLogin.Toggle()

                    Divider()
                        .frame(height: 32, alignment: .center)

                    Toggle("Show in Status Bar", isOn: $showStatusBar)
                        .onChange(of: showStatusBar) {
                            NotificationCenter.default.post(name: .statusBarSettingChangedNotification, object: nil)
                        }
                    Toggle(isOn: $showStatusbarSong) {
                        Text("Show Song in Status Bar")
                        Text("If this is disabled, only the icon will be shown.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .disabled(!showStatusBar)
                    .onChange(of: showStatusbarSong) {
                        NotificationCenter.default.post(name: .statusBarSettingChangedNotification, object: nil)
                    }

                    Divider()
                        .frame(height: 32, alignment: .center)

                    Toggle(isOn: $runAsAgent) {
                        Text("Run as Agent")
                        Text("When enabled, the app runs without a dock icon (menu bar only). Requires a restart to take effect.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .onChange(of: runAsAgent) {
                        guard !isRestarting else {
                            return
                        }

                        isRestarting = true
                        restartAlertShown = true
                    }
                #endif
            }
            .padding(32)
            .navigationTitle("Behavior")
            #if os(macOS)
                .alert("Restart Required", isPresented: $restartAlertShown) {
                    Button("Cancel", role: .cancel) {
                        runAsAgent = !runAsAgent

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isRestarting = false
                        }
                    }

                    Button("Quit swmpc", role: .destructive) {
                        NSApp.terminate(nil)
                    }
                } message: {
                    Text("You need to restart the app for this change to take effect.")
                }
            #endif
        }
    }

    struct IntelligenceView: View {
        @AppStorage(Setting.isIntelligenceEnabled) var isIntelligenceEnabled = false
        @AppStorage(Setting.intelligenceModel) var intelligenceModel = IntelligenceModel.openAI

        @State private var intelligenceToken = ""

        var body: some View {
            Form {
                Toggle(isOn: $isIntelligenceEnabled) {
                    Text("Enable AI Features")
                    Text("Currently used for smart playlist and queue generation.")
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

                SecureField("API Token:", text: $intelligenceToken)
                    .textContentType(.password)
                    .disabled(!isIntelligenceEnabled)
                    .onAppear {
                        @AppStorage(intelligenceModel.setting) var token = ""
                        token = intelligenceToken
                    }
                    .onChange(of: intelligenceToken) { _, value in
                        @AppStorage(intelligenceModel.setting) var token = ""
                        token = value.isEmpty ? "" : value
                    }
                    .onChange(of: intelligenceModel) {
                        @AppStorage(intelligenceModel.setting) var token = ""
                        token = intelligenceToken
                    }
            }
            .padding(32)
            .navigationTitle("Intelligence")
        }
    }
}
