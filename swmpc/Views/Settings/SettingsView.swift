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

#if os(macOS)
    private extension Layout.Size {
        static let settingsRowHeight: CGFloat = 32
        static let settingsWindowWidth: CGFloat = 500
    }
#endif

struct SettingsView: View {
    enum SettingCategory: String, Identifiable {
        case connection = "Connection"
        #if os(macOS)
            case behavior = "Behavior"
        #endif
        case intelligence = "Intelligence"

        var id: Self { self }
        var title: String { rawValue }

        #if os(iOS)
            static var allCases: [SettingCategory] {
                [.connection, .intelligence]
            }

        #elseif os(macOS)
            static var allCases: [SettingCategory] {
                [.connection, .behavior, .intelligence]
            }
        #endif

        var image: SFSymbol {
            switch self {
            case .connection: .point3ConnectedTrianglepathDotted
            #if os(macOS)
                case .behavior: .sliderHorizontal3
            #endif
            case .intelligence: .sparkles
            }
        }

        var view: AnyView {
            switch self {
            case .connection:
                AnyView(ConnectionView())
            #if os(macOS)
                case .behavior:
                    AnyView(BehaviorView())
            #endif
            case .intelligence:
                AnyView(IntelligenceView())
            }
        }
    }

    #if os(macOS)
        @State private var selection: SettingCategory? = .connection
    #endif

    var body: some View {
        #if os(iOS)
            NavigationView {
                Form {
                    ForEach(SettingCategory.allCases) { category in
                        NavigationLink(destination: category.view
                            .navigationTitle(category.title)
                            .navigationBarTitleDisplayMode(.inline))
                        {
                            Label(category.title, systemSymbol: category.image)
                        }
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
        #elseif os(macOS)
            TabView(selection: $selection) {
                ForEach(SettingCategory.allCases) { category in
                    category.view
                        .tabItem {
                            Label(category.title, systemSymbol: category.image)
                        }
                        .tag(category)
                        .padding(Layout.Padding.large * 2)
                        .navigationTitle(category.title)
                }
            }
            .frame(width: Layout.Size.settingsWindowWidth)
        #endif
    }

    struct ConnectionView: View {
        @AppStorage(Setting.host) var host = "localhost"
        @AppStorage(Setting.port) var port = 6600
        @AppStorage(Setting.password) var password = ""
        @AppStorage(Setting.artworkGetter) var artworkGetter = ArtworkGetter.library

        var body: some View {
            Form {
                Section {
                    TextField("MPD Host".settingsLabel, text: $host)
                        .help("Hostname or IP address of your MPD server")
                    #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    #endif
                    TextField("MPD Port".settingsLabel, value: $port, formatter: NumberFormatter())
                        .help("Port number for MPD connection (default: 6600)")
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                }

                Section {
                    SecureField("MPD Password".settingsLabel, text: $password)
                        .help("Password for MPD server authentication")
                } footer: {
                    Text("Leave empty if no password is set.")
                    #if os(macOS)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                    #endif
                }

                #if os(macOS)
                    Divider()
                        .frame(height: Layout.Size.settingsRowHeight, alignment: .center)
                #endif

                Section {
                    Picker("Artwork retrieval".settingsLabel, selection: $artworkGetter) {
                        Text("Library").tag(ArtworkGetter.library)
                        Text("Embedded").tag(ArtworkGetter.embedded)
                    }
                    .help("Choose how to retrieve album artwork")
                    #if os(macOS)
                        .pickerStyle(.inline)
                    #endif
                } footer: {
                    Text("Library will fetch artwork by searching the directory the songs resides in for a file called cover.png, cover.jpg, or cover.webp. Embedded will fetch the artwork from the song metadata. Using embedded is not recommended as it is generally much slower.")
                    #if os(macOS)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                    #endif
                }
            }
        }
    }

    #if os(macOS)
        struct BehaviorView: View {
            @AppStorage(Setting.showStatusBar) var showStatusBar = true
            @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true
            @AppStorage(Setting.runAsAgent) var runAsAgent = false

            @State private var restartAlertShown = false
            @State private var isRestarting = false

            var body: some View {
                Form {
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
                }
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
            }
        }
    #endif

    struct IntelligenceView: View {
        @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false
        @AppStorage(Setting.intelligenceModel) var intelligenceModel = IntelligenceModel.openAI

        @State private var intelligenceToken = ""

        var body: some View {
            Form {
                Section {
                    Toggle(isOn: $isIntelligenceEnabled) {
                        Text("Enable AI Features")
                    }
                    .help("Enable AI-powered features for playlist generation")
                } footer: {
                    Text("Currently used for smart playlist and queue generation.")
                    #if os(macOS)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                    #endif
                }

                #if os(macOS)
                    Divider()
                        .frame(height: Layout.Size.settingsRowHeight, alignment: .center)
                #endif

                Section {
                    Picker("Model".settingsLabel, selection: $intelligenceModel) {
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
                    #if os(macOS)
                        .pickerStyle(.inline)
                    #endif
                        .disabled(!isIntelligenceEnabled)

                    SecureField("API Token".settingsLabel, text: $intelligenceToken)
                        .textContentType(.password)
                        .help("API token for the selected AI service")
                        .disabled(!isIntelligenceEnabled)
                }
            }
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
    }
}
