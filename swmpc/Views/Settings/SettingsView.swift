//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import ButtonKit
import Network
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

                    Section {
                        NavigationLink(destination: AboutView()
                            .navigationTitle("About")
                            .navigationBarTitleDisplayMode(.inline))
                        {
                            Label("About", systemSymbol: .infoCircle)
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

        @State private var bonjour = BonjourManager()

        @State private var host = UserDefaults.standard.string(forKey: Setting.host) ?? "localhost"
        @State private var port = UserDefaults.standard.integer(forKey: Setting.port) == 0 ? 6600 : UserDefaults.standard.integer(forKey: Setting.port)
        @State private var password = UserDefaults.standard.string(forKey: Setting.password) ?? ""

        var body: some View {
            Form {
                #if os(iOS)
                    Section {
                        HStack {
                            Text("Status")
                            Spacer()
                            HStack(spacing: Layout.Padding.small) {
                                Circle()
                                    .fill(mpd.state.connectionColor)
                                    .frame(width: 8, height: 8)
                                Text(mpd.state.connectionDescription)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !mpd.state.isConnectionReady, let error = mpd.state.error {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .monospaced()
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        TextField("Host", text: $host)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        TextField("Port", value: $port, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    } header: {
                        Text("Server")
                    } footer: {
                        Text("The hostname and port of your MPD server.")
                    }

                    Section {
                        SecureField("Password", text: $password)
                    } header: {
                        Text("Authentication")
                    } footer: {
                        Text("Leave empty if your server doesn't require authentication.")
                    }

                    Section {
                        AsyncButton {
                            UserDefaults.standard.set(host, forKey: Setting.host)
                            UserDefaults.standard.set(port, forKey: Setting.port)
                            UserDefaults.standard.set(password, forKey: Setting.password)

                            await mpd.reinitialize()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Connect")
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("Save settings and connect to the server.")
                    }

                    Section {
                        Button {
                            bonjour.scan()
                        } label: {
                            HStack {
                                Text("Scan for Servers")
                                Spacer()
                                if bonjour.isScanning {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(bonjour.isScanning)
                    } header: {
                        Text("Discovery")
                    } footer: {
                        Text("Search for MPD servers on your local network using Bonjour.")
                    }

                    if !bonjour.servers.isEmpty {
                        Section {
                            ForEach(bonjour.servers) { server in
                                Button {
                                    host = server.host
                                    port = server.port
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(server.displayName)
                                                .foregroundStyle(.primary)
                                            Text("\(server.host):\(server.port)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemSymbol: .chevronRight)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        } header: {
                            Text("Available Servers")
                        }
                    }

                    Section {
                        Picker("Retrieval Method", selection: $artworkGetter) {
                            Text("Library").tag(ArtworkGetter.library)
                            Text("Metadata").tag(ArtworkGetter.metadata)
                        }
                        .pickerStyle(.navigationLink)
                    } header: {
                        Text("Artwork")
                    } footer: {
                        Text("Library searches for cover.png, cover.jpg, or cover.webp in the song's directory. Metadata extracts artwork from the song file, but is slower.")
                    }
                #elseif os(macOS)
                    Section {
                        TextField(text: $host, label: {
                            SettingsLabel("MPD Host")
                        })
                        .help("Hostname or IP address of your MPD server")
                        TextField(value: $port, formatter: NumberFormatter(), label: {
                            SettingsLabel("MPD Port")
                        })
                        .help("Port number for MPD connection (default: 6600)")
                    }

                    Section {
                        SecureField(text: $password, label: {
                            SettingsLabel("MPD Password")
                        })
                        .help("Password for MPD server authentication")
                    }

                    Section {
                        HStack {
                            Button {
                                bonjour.scan()
                            } label: {
                                if bonjour.isScanning {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Scan for Servers")
                                }
                            }
                            .disabled(bonjour.isScanning)

                            AsyncButton("Connect") {
                                UserDefaults.standard.set(host, forKey: Setting.host)
                                UserDefaults.standard.set(port, forKey: Setting.port)
                                UserDefaults.standard.set(password, forKey: Setting.password)

                                await mpd.reinitialize()
                            }

                            Circle()
                                .fill(mpd.state.connectionColor)
                                .frame(width: 10, height: 10)
                                .help(mpd.state.connectionDescription)
                        }

                        if !mpd.state.isConnectionReady, let error = mpd.state.error {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .monospaced()
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                        Text("Leave password field empty if no password is set. Click Connect to test the connection and apply changes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }

                    if !bonjour.servers.isEmpty {
                        Divider()
                            .frame(height: Layout.Size.settingsRowHeight, alignment: .center)

                        Section {
                            ForEach(bonjour.servers) { server in
                                Button {
                                    host = server.host
                                    port = server.port
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 8, height: 8)
                                        VStack(alignment: .leading) {
                                            Text(server.displayName)
                                            Text("\(server.host):\(server.port)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()
                        .frame(height: Layout.Size.settingsRowHeight, alignment: .center)

                    Section {
                        Picker(selection: $artworkGetter, label: SettingsLabel("Artwork retrieval")) {
                            Text("Library").tag(ArtworkGetter.library)
                            Text("Metadata").tag(ArtworkGetter.metadata)
                        }
                        .help("Choose how to retrieve album artwork")
                        .pickerStyle(.inline)
                    } footer: {
                        Text("Library will fetch artwork by searching the directory the songs resides in for a file called cover.png, cover.jpg, or cover.webp. Metadata will fetch the artwork from the song metadata. Using metadata is not recommended as it is generally much slower.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }
                #endif
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
                #if os(iOS)
                    Section {
                        Toggle("Enable AI Features", isOn: $isIntelligenceEnabled)
                    } footer: {
                        Text("Powers smart playlist and queue generation using AI.")
                    }

                    Section {
                        Picker("Model", selection: $intelligenceModel) {
                            ForEach(IntelligenceModel.allCases.filter(\.isEnabled)) { model in
                                VStack(alignment: .leading) {
                                    Text(model.name)
                                    Text(model.model)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .disabled(!isIntelligenceEnabled)

                        SecureField("API Token", text: $intelligenceToken)
                            .textContentType(.password)
                            .disabled(!isIntelligenceEnabled)
                    } header: {
                        Text("Provider")
                    } footer: {
                        Text("Enter your API token for the selected AI provider.")
                    }
                #elseif os(macOS)
                    Section {
                        Toggle(isOn: $isIntelligenceEnabled) {
                            Text("Enable AI Features")
                        }
                        .help("Enable AI-powered features for playlist generation")
                    } footer: {
                        Text("Powers smart playlist and queue generation using AI.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }

                    Divider()
                        .frame(height: Layout.Size.settingsRowHeight, alignment: .center)

                    Section {
                        Picker(selection: $intelligenceModel, label: SettingsLabel("Model")) {
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
                        .disabled(!isIntelligenceEnabled)

                        SecureField(text: $intelligenceToken, label: {
                            SettingsLabel("API Token")
                        })
                        .textContentType(.password)
                        .help("API token for the selected AI service")
                        .disabled(!isIntelligenceEnabled)
                    }
                #endif
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
