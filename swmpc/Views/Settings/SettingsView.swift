//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI

#if os(macOS)
    import LaunchAtLogin
#endif

#if os(macOS)
    private extension Layout.Size {
        static let settingsRowHeight: CGFloat = 32
        static let settingsWindowWidth: CGFloat = 600
    }
#endif

struct SettingsView: View {
    #if os(macOS)
        @State private var selection: SettingCategory? = .connection
    #endif

    private enum SettingCategory: String, Identifiable {
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

        @ViewBuilder
        var view: some View {
            switch self {
            case .connection:
                ConnectionView()
            #if os(macOS)
                case .behavior:
                    BehaviorView()
            #endif
            case .intelligence:
                IntelligenceView()
            }
        }
    }

    var body: some View {
        #if os(iOS)
            NavigationStack {
                List {
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
        @Environment(MPD.self) private var mpd
        #if os(iOS)
            @Environment(NavigationManager.self) private var navigator
        #endif

        @AppStorage(Setting.artworkGetter) var artworkGetter = ArtworkGetter.library

        @State private var host = UserDefaults.standard.string(forKey: Setting.host) ?? "localhost"
        @State private var port = UserDefaults.standard.integer(forKey: Setting.port) == 0 ? 6600 : UserDefaults.standard.integer(forKey: Setting.port)
        @State private var password = UserDefaults.standard.string(forKey: Setting.password) ?? ""

        @State private var connectionStatus: ConnectionStatus = .connecting

        private enum ConnectionStatus {
            case connecting
            case success
            case failure

            var color: Color {
                switch self {
                case .connecting: .yellow
                case .success: .green
                case .failure: .red
                }
            }
        }

        var body: some View {
            Form {
                Section {
                    TextField(text: $host, label: {
                        SettingsLabel("MPD Host")
                    })
                    .help("Hostname or IP address of your MPD server")
                    #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    #endif
                    TextField(value: $port, formatter: NumberFormatter(), label: {
                        SettingsLabel("MPD Port")
                    })
                    .help("Port number for MPD connection (default: 6600)")
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                }

                Section {
                    SecureField(text: $password, label: {
                        SettingsLabel("MPD Password")
                    })
                    .help("Password for MPD server authentication")
                } footer: {
                    #if os(iOS)
                        Text("Leave empty if no password is set.")
                    #endif
                }

                Section {
                    HStack {
                        AsyncButton("Connect") {
                            connectionStatus = .connecting

                            UserDefaults.standard.set(host, forKey: Setting.host)
                            UserDefaults.standard.set(port, forKey: Setting.port)
                            UserDefaults.standard.set(password, forKey: Setting.password)

                            await mpd.reinitialize()
                            try? await Task.sleep(for: .seconds(2))

                            updateConnectionStatus()
                        }

                        #if os(iOS)
                            Spacer()
                        #endif

                        Circle()
                            .fill(connectionStatus.color)
                            .frame(width: 10, height: 10)
                    }

                    if case .failure = connectionStatus, let error = mpd.error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .monospaced()
                            .foregroundColor(.secondary)
                            .padding(7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(white: 0.1, opacity: 0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1),
                                    ),
                            )
                    }
                } footer: {
                    #if os(iOS)
                        Text("Test connection and apply settings.")
                    #elseif os(macOS)
                        Text("Leave password field empty if no password is set. Click Connect to test the connection and apply changes.")
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
                    Picker(selection: $artworkGetter, label: SettingsLabel("Artwork retrieval")) {
                        Text("Library").tag(ArtworkGetter.library)
                        Text("Embedded").tag(ArtworkGetter.embedded)
                    }
                    .help("Choose how to retrieve album artwork")
                    #if os(iOS)
                        .pickerStyle(.navigationLink)
                    #else
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
            .onAppear {
                updateConnectionStatus()
            }
            .onChange(of: mpd.status.state) {
                updateConnectionStatus()
            }
            .onChange(of: mpd.error) {
                updateConnectionStatus()
            }
        }

        private func updateConnectionStatus() {
            if mpd.error != nil {
                connectionStatus = .failure
            } else if mpd.status.state != nil {
                connectionStatus = .success
            } else {
                connectionStatus = .connecting
            }
        }
    }

    #if os(macOS)
        struct BehaviorView: View {
            @AppStorage(Setting.showStatusBar) var showStatusBar = true
            @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true

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
                    Text("Powers smart playlist and queue generation using AI.")
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
                    Picker(selection: $intelligenceModel, label: SettingsLabel("Model")) {
                        ForEach(IntelligenceModel.allCases.filter(\.isEnabled)) { model in
                            #if os(iOS)
                                VStack(alignment: .leading) {
                                    Text(model.name)
                                    Text(model.model)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(model)
                            #elseif os(macOS)
                                HStack {
                                    Text(model.name)
                                    Text(model.model)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(model)
                            #endif
                        }
                    }
                    .help("Select the AI model to use for intelligent features")
                    #if os(iOS)
                        .pickerStyle(.navigationLink)
                    #elseif os(macOS)
                        .pickerStyle(.inline)
                    #endif
                        .disabled(!isIntelligenceEnabled)

                    SecureField(text: $intelligenceToken, label: {
                        SettingsLabel("API Token")
                    })
                    .textContentType(.password)
                    .help("API token for the selected AI service")
                    .disabled(!isIntelligenceEnabled)
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
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
