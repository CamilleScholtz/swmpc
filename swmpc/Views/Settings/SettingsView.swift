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

private extension Layout.Padding {
    static let massive: CGFloat = 32
}

private extension Layout.Size {
    static let settingsRowHeight: CGFloat = 32
    static let settingsWindowWidth: CGFloat = 500
}

struct SettingsView: View {
    enum SettingCategory: String, Identifiable {
        case general = "General"
        case behavior = "Behavior"
        case intelligence = "Intelligence"

        var id: Self { self }
        var title: String { rawValue }

        #if os(iOS)
            static var allCases: [SettingCategory] {
                [.general, .intelligence]
            }

        #elseif os(macOS)
            static var allCases: [SettingCategory] {
                [.general, .behavior, .intelligence]
            }
        #endif

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
        #if os(iOS)
            NavigationView {
                List {
                    ForEach(SettingCategory.allCases) { category in
                        NavigationLink(destination: category.view) {
                            Label(category.title, systemSymbol: category.image)
                        }
                    }
                }
                .navigationTitle("Settings")
            }
        #elseif os(macOS)
            TabView(selection: $selection) {
                ForEach(SettingCategory.allCases) { category in
                    category.view
                        .tabItem {
                            Label(category.title, systemSymbol: category.image)
                        }
                        .tag(category)
                }
            }
            .frame(width: Layout.Size.settingsWindowWidth)
        #endif
    }

    struct GeneralView: View {
        @AppStorage(Setting.host) var host = "localhost"
        @AppStorage(Setting.port) var port = 6600
        @AppStorage(Setting.password) var password = ""

        @AppStorage(Setting.artworkGetter) var artworkGetter = ArtworkGetter.library

        var body: some View {
            Form {
                TextField("MPD Host:", text: $host)
                    .help("Hostname or IP address of your MPD server")
                TextField("MPD Port:", value: $port, formatter: NumberFormatter())
                    .help("Port number for MPD connection (default: 6600)")

                SecureField("MPD Password:", text: $password)
                    .help("Password for MPD server authentication")
                Text("Leave empty if no password is set.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()
                    .frame(height: Layout.Size.settingsRowHeight, alignment: .center)

                Picker("Artwork retrieval:", selection: $artworkGetter) {
                    Text("Library").tag(ArtworkGetter.library)
                    Text("Embedded").tag(ArtworkGetter.embedded)
                }
                .help("Choose how to retrieve album artwork")
                .pickerStyle(.inline)
                Text("Library will fetch artwork by searching the directory the songs resides in for a file called cover.png, cover.jpg, or cover.webp. Embedded will fetch the artwork from the song metadata. Using embedded is not recommended as it is generally much slower.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .frame(height: Layout.Size.settingsRowHeight, alignment: .center)
            }
            .padding(Layout.Padding.massive)
            .navigationTitle("General")
        }
    }

    struct BehaviorView: View {
        #if os(macOS)
            @AppStorage(Setting.showStatusBar) var showStatusBar = true
            @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true
            @AppStorage(Setting.runAsAgent) var runAsAgent = false

            @State private var restartAlertShown = false
            @State private var isRestarting = false
        #endif

        var body: some View {
            Form {
                #if os(macOS)
                    LaunchAtLogin.Toggle()
                        .help("Automatically start swmpc when you log in")

                    Divider()
                        .frame(height: 32, alignment: .center)

                    Toggle("Show in Status Bar", isOn: $showStatusBar)
                        .help("Display swmpc icon in the menu bar")
                        .onChange(of: showStatusBar) {
                            NotificationCenter.default.post(name: .statusBarSettingChangedNotification, object: nil)
                        }
                    Toggle(isOn: $showStatusbarSong) {
                        Text("Show Song in Status Bar")
                        Text("If this is disabled, only the icon will be shown.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .help("Display currently playing song next to the menu bar icon")
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
                    .help("Run without dock icon (menu bar only mode)")
                    .onChange(of: runAsAgent) {
                        guard !isRestarting else {
                            return
                        }

                        isRestarting = true
                        restartAlertShown = true
                    }
                #endif
            }
            .padding(Layout.Padding.massive)
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
        @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabledSetting = false
        @AppStorage(Setting.intelligenceModel) var intelligenceModel = IntelligenceModel.openAI

        @State private var intelligenceToken = ""

        var isIntelligenceEnabled: Bool {
            guard isIntelligenceEnabledSetting else {
                return false
            }

            return !intelligenceToken.isEmpty
        }

        var body: some View {
            Form {
                Toggle(isOn: $isIntelligenceEnabledSetting) {
                    Text("Enable AI Features")
                    Text("Currently used for smart playlist and queue generation.")
                }
                .help("Enable AI-powered features for playlist generation")

                Divider()
                    .frame(height: Layout.Size.settingsRowHeight, alignment: .center)

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
                .help("Select the AI model to use for intelligent features")
                .pickerStyle(.inline)
                .disabled(!isIntelligenceEnabledSetting)

                SecureField("API Token:", text: $intelligenceToken)
                    .textContentType(.password)
                    .help("API token for the selected AI service")
                    .disabled(!isIntelligenceEnabledSetting)
                    .onAppear {
                        @AppStorage(intelligenceModel.setting) var token = ""
                        intelligenceToken = token
                    }
                    .onChange(of: intelligenceToken) { _, value in
                        @AppStorage(intelligenceModel.setting) var token = ""
                        token = value.isEmpty ? "" : value
                    }
                    .onChange(of: intelligenceModel) {
                        @AppStorage(intelligenceModel.setting) var token = ""
                        intelligenceToken = token
                    }
            }
            .padding(Layout.Padding.massive)
            .navigationTitle("Intelligence")
        }
    }
}
